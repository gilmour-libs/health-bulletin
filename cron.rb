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

# Check if any of the listeners have maxed out.
Cron.add_job HealthInterval do
  client = Subpub.get_client
  backend = client.get_backend('redis')

  backend.publisher.hgetall backend.class::RedisHealthKey do |r|
    known_hosts = Hash.new(0)
    r.each_slice(2) do |slice|
      known_hosts[slice[0]] = slice[1]
    end
  end

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
