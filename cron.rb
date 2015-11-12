require 'em-hiredis'
require 'mash'
require 'logger'
require 'singleton'

require 'gilmour/waiter'

require_relative './subpub'
require_relative './backtrace'
require_relative './lib/cli'
require_relative './lib/logger'

# Base module that provides common Cron functionalities.
module Cron
  @@jobs = []

  # CHeck to ensure that Health Monitor can speak with Redis itself.
  # There have been instances where the monitor is deployed inside a VPC
  # instance that cannot talk to redis itself, and that's bad.
  class RedisCheck
    def threshold
      latency = CLI::Args['redis_health_interval']
      frequency = EM::Hiredis.reconnect_timeout
      latency / frequency
    end

    def initialize
      @count = 0
      client = Subpub.get_client
      @backend = client.get_backend('redis')
      @reporter = PagerDutySender.new(CLI::Args['health_reporting'])
    end

    def emit_error(description)
      opts = { topic: self.class.name, description: description,
               sender: @backend.ident, multi_process: false, code: 500,
               timestamp: Time.now.getutc, config: CLI::Args['redis'] }

      payload = { traceback: '', extra: opts }
      @reporter.send_traceback(Mash.new(payload))
    end

    def start
      if @backend.publisher.nil?
        emit_error 'Health monitor cannot connect to Redis'
        exit
      end

      @backend.publisher.on(:failed) do
        connection_failure
      end
    end

    def connection_failure
      @count += 1
      return if @count < threshold
      @count = 0
      emit_error 'Health monitor cannot connect to Redis'
    end
  end

  def self.add_job(interval, &blk)
    HLogger.info "Registered new handler for every #{interval} seconds"
    @@jobs << { handler: blk, interval: interval }
  end

  def self.redis_check
    monitor = RedisCheck.new
    monitor.start
  end
end

# Common cron class to expose an error emission interface.
class BaseCron
  @@reporter = PagerDutySender.new(CLI::Args['health_reporting'])

  def initialize
    client = Subpub.get_client
    @backend = client.get_backend('redis')
  end

  def run
    _run
  rescue Exception => e
    HLogger.exception e
  end

  def emit_error(description, extra = nil)
    unless description.is_a?(String)
      HLogger.error 'Description must be a valid non-empty string'
      return
    end

    opts = { topic: self.class.name, request_data: {},
             userdata: extra || {}, sender: @backend.ident,
             multi_process: false, timestamp: Time.now.getutc }

    payload = { backtrace: description, code: 500 }
    payload.merge!(opts)
    @@reporter.send_traceback(Mash.new(payload))
  end
end

# Manager to ensure that essential topics have atleast one subscriber.
class TopicCron < BaseCron
  def _run
    topics = CLI::Args['essential_topics']
    return unless topics.is_a?(Array) && !topics.empty?

    EM.defer do
      essential_topics = []

      wg = Gilmour::Waiter.new
      wg.add topics.length

      topics.each do |topic|
        @backend.publisher.pubsub('numsub', topic) do |_, num|
          essential_topics.push(topic) if num == 0
          wg.done
        end
      end

      wg.wait do
        if essential_topics.length > 0
          msg = 'Required topics do not have any subscriber.'
          extra = { 'topics' => essential_topics }
          emit_error msg, extra
        end
      end
    end
  end
end

# Manager to ensure that all gilmour servers respond to health pings within a
# finite timeout. Server is declared dead if it fails to respond to 3
# consecutive health pings.
class HealthCron < BaseCron
  def _run
    @backend.publisher.hgetall @backend.class::GilmourHealthKey do |r|
      EM.defer do
        known_hosts = Hash.new(0)

        r.each_slice(2) do |slice|
          host = slice[0]
          known_hosts[host] = "gilmour.health.#{host}"
        end

        unless known_hosts.empty?
          inactive_hosts = {}

          3.times do |_|
            next if known_hosts.empty?

            wg = Gilmour::Waiter.new
            wg.add known_hosts.length

            known_hosts.each do |host, topic|
              opts = { timeout: 60, confirm_subscriber: true }
              @backend.publish('ping', topic, opts) do |_, code|
                known_hosts.delete host if code != 499
                if code != 200
                  inactive_hosts[host] = { 'code' => code, 'data' => '' }
                end
                wg.done
              end
            end

            wg.wait
          end

          unless inactive_hosts.empty?
            msg = 'Unreachable hosts'
            extra = { 'hosts' => inactive_hosts }
            emit_error msg, extra
          end

        end
      end
    end
  end
end

# Check if any of the listeners have maxed out.
#
if CLI::Args['health_reporting']['enabled'] == true
  HLogger.info 'Monitoring Health: Active'
  Cron.add_job CLI::Args['health_check_interval'] do
    runner = HealthCron.new
    runner.run
  end

  if CLI::Args['essential_topics'].length > 0
    HLogger.info 'Monitoring essential topics: Active'
    Cron.add_job CLI::Args['topic_check_interval'] do
      runner = TopicCron.new
      runner.run
    end
  end
end
