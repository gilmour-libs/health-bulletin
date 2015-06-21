require "singleton"

HealthInterval = 5
SubscriberInterval = 5

require_relative "./subpub"

module Cron
  @@jobs = []

  def self.add_job(interval, &blk)
    $stderr.puts "Registered new handler for every #{interval} seconds"
    @@jobs << {:handler => blk, :interval => interval}
  end
end

class HealthCron
  include Singleton

  attr_accessor :is_processing

  def run
    if is_processing == true
      $stderr.puts 'A health check is already in progress'
    else
      is_processing = true
      begin
        _run
      rescue Exception => e
        $stderr.puts e.message
        $stderr.puts e.backtrace
      end
      is_processing = false
    end
  end

  def _run
    client = Subpub.get_client
    backend = client.get_backend('redis')

    backend.publisher.hgetall backend.class::RedisHealthKey do |r|
      known_hosts = Hash.new(0)
      r.each_slice(2) do |slice|
        host = slice[0]
        known_hosts[host] = "gilmour.health.#{host}"
      end

      inactive_hosts = []

      known_hosts.each do |host, topic|
        opts = { :timeout => 60, :confirm_subscriber => true}
        backend.publish("ping", topic, opts) do |data, code|
          $stderr.puts "Code => #{code}, Data => #{data}"
          if code != 200
            inactive_hosts.push(host)
          end
        end
      end

      $stderr.puts "Inactive Hosts: #{inactive_hosts}"
    end
  end
end

# Check if any of the listeners have maxed out.
Cron.add_job HealthInterval do
  runner = HealthCron.instance
  runner.run
end

Cron.add_job SubscriberInterval do
  # Check whether there are active subscribers for all non-wildcard topics
  # promised by listeners.
  # For each listener, confirm that there is atleast one subscriber
  # for all topics that listener promises to listen to

  #con = DsRedis.connection
  #puts con
  puts "Ensuring Subscribers"
end
