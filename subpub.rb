require "singleton"

require_relative "./backtrace"
require_relative "./lib/cli"

begin
  require_relative "../gilmour/lib/gilmour"
  puts "Found local version of gilmour"
rescue LoadError
  require "gilmour"
end

module Subpub
  GilmourBackend = 'redis'
  # TODO: Please read this Flag from Command line or conf file.
  #
  def self.get_client
    SubpubClient.instance
  end

  class SubpubClient
    include Singleton
    include Gilmour::Base

    @@reporter = PagerDutySender.new(CLI::Args["error_reporting"])

    def activate
      # Monitor server should not broadcast errors or participate in Health
      # checks, as this leads to recursion.
      redis_opts = { 'broadcast_errors' => false, 'health_check' => false}
      enable_backend(GilmourBackend, redis_opts)

      registered_subscribers.each do |sub|
        sub.backend = 'redis'
      end

      start()
    end
  end

  class ErrorSubsciber < SubpubClient

    $stderr.puts "Listening to #{Gilmour::ErrorChannel}"
    listen_to Gilmour::ErrorChannel do
      @@reporter.send_traceback(request.body)
    end

  end
end
