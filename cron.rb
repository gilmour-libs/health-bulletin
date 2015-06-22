require "singleton"

HealthInterval = 5
SubscriberInterval = 5

require_relative "./subpub"
require_relative "./config"
require_relative "./wait_group"

module Cron
  @@jobs = []

  def self.add_job(interval, &blk)
    $stderr.puts "Registered new handler for every #{interval} seconds"
    @@jobs << {:handler => blk, :interval => interval}
  end
end

class BaseCron
  def run
    begin
      _run
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace
    end
  end
end

class TopicCron < BaseCron
  include Singleton

  def _run
    client = Subpub.get_client
    backend = client.get_backend('redis')

    if Config["essential_topics"].length
      essential_topics = []

      wg = WaitGroup.new
      wg.add Config["essential_topics"].length

      Config["essential_topics"].each do |topic|
        backend.publisher.pubsub('numsub', topic) do |_, num|
          essential_topics.push(topic) if num == 0
          wg.done
        end
      end

      wg.wait do
        $stderr.puts "Essential topics missing: #{essential_topics}"
      end
    end

  end
end

class HealthCron < BaseCron
  include Singleton

  def _run
    client = Subpub.get_client
    backend = client.get_backend('redis')

    backend.publisher.hgetall backend.class::RedisHealthKey do |r|
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
          backend.publish("ping", topic, opts) do |data, code|
            inactive_hosts.push(host) if code != 200
            wg.done
          end
        end

        wg.wait do
          $stderr.puts "Inactive Hosts: #{inactive_hosts}"
        end

      end
    end
  end
end

# Check if any of the listeners have maxed out.
Cron.add_job HealthInterval do
  runner = HealthCron.instance
  runner.run
end

Cron.add_job SubscriberInterval do
  runner = TopicCron.instance
  runner.run
end
