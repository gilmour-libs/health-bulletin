require "gilmour"
require_relative "backtrace"

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
    listen_to Gilmour::ErrorChannel exclusive: true do
      $stderr.puts request
      Backtrace.send_traceback(request.body, {})
    end
  end
end
