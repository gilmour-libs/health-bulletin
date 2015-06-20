require 'json'
require 'eventmachine'
require 'evma_httpserver'

require_relative "./cron_keeper"
require_relative "./error_keeper"

module HTTP
  class Server < EM::Connection
    include EM::HttpServer

    def post_init
      super
      no_environment_strings
    end

    def process_http_request
      response = EM::DelegatedHttpResponse.new(self)
      response.status = 200
      response.content_type 'application/json'
      response.content = JSON.generate({:status => 200})
      response.send_response
    end
  end

  def register_jobs(jobs={})
    jobs.each()
  end
end

module ErrorKeeper
  class << self
    def start(event_machine)
      Server.new
    end
  end
end

module CronKeeper
  class << self
    def activate_jobs(event_machine)
      @@jobs.each do |val|
        EM.add_periodic_timer(val[:interval], &val[:handler])
      end
    end
  end
end

def shut_down_em
  puts "Gracefully shutting down event machine."
end

def bind_signals
  signal_handler = proc { |signo|
    sig = Signal.signame(signo)
    puts "Caught #{sig} -> #{signo}, Exiting"
    exit
  }

  (1..3).each do |num|
    Signal.trap(num, signal_handler)
  end

  Signal.trap(0, proc {
    shut_down_em
    exit
  })

end

EM.run do
  ErrorKeeper.start EM
  CronKeeper.activate_jobs EM
  bind_signals
  EM.start_server '0.0.0.0', 8080, HTTP::Server
end
