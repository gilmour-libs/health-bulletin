require "singleton"

require_relative "./backtrace"

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
  BroadcastErrors = false

  def self.get_client
    SubpubClient.instance
  end

  class SubpubClient
    include Singleton
    include Gilmour::Base

    def activate
      enable_backend(GilmourBackend, { })
      registered_subscribers.each do |sub|
        sub.backend = 'redis'
      end

      $stderr.puts "Starting server. This will start listening to Error messages."
      start()
    end
  end

  class ErrorSubsciber < SubpubClient
    listen_to Gilmour::ErrorChannel, exclusive: true do
      if Subpub::BroadcastErrors
        Backtrace.send_traceback(request, {})
      end

    end
  end
end
