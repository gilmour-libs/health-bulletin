require_relative "backtrace"

begin
  require_relative "../gilmour/lib/gilmour"
  puts "Found local version of gilmour"
rescue LoadError
  require "gilmour"
end

module ErrorKeeper
  GilmourBackend = 'redis'

  class Server
    include Gilmour::Base

    def initialize
      enable_backend(GilmourBackend, { })
      registered_subscribers.each do |sub|
        sub.backend = 'redis'
      end
      $stderr.puts "Starting server. This will start listening to Error messages."
      start()
    end
  end

  class ErrorSubsciber < Server
    listen_to Gilmour::ErrorChannel, exclusive: true do
      Backtrace.send_traceback(request, {})
    end
  end
end
