require "singleton"

require_relative "./backtrace"
require_relative "./lib/cli"
require_relative "./lib/logger"

begin
  require_relative "../gilmour/lib/gilmour"
  HLogger.debug "Found local version of gilmour"
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
      redis_args = CLI::Args['redis']

      host = redis_args['host']
      port = redis_args['port']

      enable_backend(GilmourBackend, {
        broadcast_errors: false,
        health_check: false,
        host: host,
        port: port,
        db: redis_args['db']
      })

      $stderr.puts "Connecting to messenger on #{host}:#{port} ..."

      registered_subscribers.each do |sub|
        sub.backend = 'redis'
      end

      start()
    end
  end

  class ErrorSubsciber < SubpubClient

    HLogger.debug "Listening to #{Gilmour::ErrorChannel}"
    listen_to Gilmour::ErrorChannel do
      @@reporter.send_traceback(request.body)
    end

  end
end
