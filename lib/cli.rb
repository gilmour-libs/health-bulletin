require 'trollop'
require 'yaml'

module CLI
  class << self
    def make_options
      opts = Trollop::options do
        version "Health Monitor 0.1.0 (c) datascale.io"
        opt :config, "Read the configurations from here", :type => :string
        opt :v, "Use verbose logging [info]" #flag
        opt :vv, "Use very verbose logging [debug]" #flag_mode
      end

      Trollop::die :config, "must exist" unless File.exist?(opts[:config]) if opts[:config]
      opts
    end

    DefaultConfig = <<-EOF
---
essential_topics:

health_check_interval: 60
topic_check_interval: 60

log_level: warn

redis:
  host: '127.0.0.1'
  port: 6379
  db: 0

listen_to:
  host: '0.0.0.0'
  port: 8080

health_reporting:
  pager_duty_token:
  enabled: true

error_reporting:
  pager_duty_token:
  enabled: true
    EOF

    def make_args
      options = make_options
      config = YAML.load(DefaultConfig)

      if !options[:config] || options[:config].empty?
        $stderr.puts "Will use default config"
      else
        yaml_content = File.read(options[:config])
        config = config.merge(YAML.load(yaml_content))
      end

      if ENV['REDIS_HOST']
          config["redis"]["host"] = ENV["REDIS_HOST"]
      end

      if ENV["REDIS_PORT"]
        config["redis"]["port"] = ENV["REDIS_PORT"].to_i
      end

      config["essential_topics"] ||= []

      if options[:vv]
        config['log_level'] = 'debug'
      elsif options[:v]
        config['log_level'] = 'info'
      end

      $stderr.puts "Using config: #{config}"

      config
    end
  end

  Args = self.make_args
end
