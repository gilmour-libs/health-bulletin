HealthInterval = 5
SubscriberInterval = 5

module CronKeeper
  @@jobs = []

  def self.add_job(interval, &blk)
    $stderr.puts "Registered new handler for every #{interval} seconds"
    @@jobs << {:handler => blk, :interval => interval}
  end
end

# Check if any of the listeners have maxed out.
CronKeeper.add_job HealthInterval do
  puts "Ensuring listeners health."
end

CronKeeper.add_job SubscriberInterval do
  # Check whether there are active subscribers for all non-wildcard topics
  # promised by listeners.
  # For each listener, confirm that there is atleast one subscriber
  # for all topics that listener promises to listen to

  #con = DsRedis.connection
  #puts con
  puts "Ensuring Subscribers"
end
