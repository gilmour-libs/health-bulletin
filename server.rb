require 'json'
require 'eventmachine'
require 'evma_httpserver'

require_relative "./cron"
require_relative "./subpub"
require_relative "./lib/cli"
require_relative "./lib/logger"

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

module Subpub
  def self.start(event_machine)
    client = Subpub.get_client
    client.activate
  end
end

module Cron
  def self.activate_jobs(event_machine)
    @@jobs.each do |val|
      EM.add_periodic_timer(val[:interval], &val[:handler])
    end
  end
end

def shut_down_em
  $stderr.puts "Gracefully shutting down event machine."
end

def bind_signals
  signal_handler = proc { |signo|
    sig = Signal.signame(signo)
    $stderr.puts "Caught #{sig} -> #{signo}, Exiting"
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
  Subpub.start EM
  Cron.activate_jobs EM
  Cron.redis_check
  bind_signals
  listen_to = CLI::Args['listen_to']
  HLogger.warn "Serving on #{listen_to['host']}:#{listen_to['port']}"
  EM.start_server listen_to['host'], listen_to['port'], HTTP::Server
end
