require "mash"
require "logger"
require "singleton"

require_relative "./subpub"
require_relative "./backtrace"
require_relative "./lib/cli"
require_relative "./lib/logger"
require_relative "./lib/wait_group"

module Cron
  @@jobs = []

  def self.add_job(interval, &blk)
    HLogger.info "Registered new handler for every #{interval} seconds"
    @@jobs << {:handler => blk, :interval => interval}
  end
end

class BaseCron
  @@reporter = PagerDutySender.new(CLI::Args["health_reporting"])

  def initialize
    client = Subpub.get_client
    @backend = client.get_backend('redis')
  end

  def run
    begin
      _run
    rescue Exception => e
      HLogger.exception e
    end
  end

  def emit_error(description, extra=nil)
    if !description.is_a?(String)
      HLogger.error "Description must be a valid non-empty string"
      return
    end

    opts = {
      :topic => self.class.name,
      :description => description,
      :sender => @backend.ident,
      :multi_process => false,
      :code => 500
    }.merge(extra || {})

    # Publish all errors on gilmour.error
    # This may or may not have a listener based on the configuration
    # supplied at setup.
    opts[:timestamp] = Time.now.getutc
    payload = {:traceback => '', :extra => opts}
    @@reporter.send_traceback(Mash.new(payload))
  end

end

class TopicCron < BaseCron
  #include Singleton

  def _run
    if CLI::Args["essential_topics"].length
      essential_topics = []

      wg = WaitGroup.new
      wg.add CLI::Args["essential_topics"].length

      CLI::Args["essential_topics"].each do |topic|
        @backend.publisher.pubsub('numsub', topic) do |_, num|
          essential_topics.push(topic) if num == 0
          wg.done
        end
      end

      wg.wait do
        if essential_topics.length
          msg = "Required topics do not have any subscriber."
          extra = {"topics" => essential_topics}
          emit_error msg, extra
        end
      end
    end

  end
end

class HealthCron < BaseCron
  #include Singleton

  def _run
    @backend.publisher.hgetall @backend.class::GilmourHealthKey do |r|
      known_hosts = Hash.new(0)

      r.each_slice(2) do |slice|
        host = slice[0]
        known_hosts[host] = "gilmour.health.#{host}"
      end

      if known_hosts.length > 0
        inactive_hosts = []

        wg = WaitGroup.new
        wg.add known_hosts.length

        known_hosts.each do |host, topic|
          opts = { :timeout => 60, :confirm_subscriber => true}
          @backend.publish("ping", topic, opts) do |data, code|
            inactive_hosts.push(host) if code != 200
            wg.done
          end
        end

        wg.wait do
          if inactive_hosts.length
            msg = "Unreachable hosts"
            extra = {"hosts" => inactive_hosts}
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
  Cron.add_job CLI::Args['health_check_interval'] do
    runner = HealthCron.new
    runner.run
  end


  if CLI::Args['essential_topics'].length > 0
    Cron.add_job CLI::Args['topic_check_interval'] do
      runner = TopicCron.new
      runner.run
    end
  end
end
