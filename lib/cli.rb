require 'getoptlong'
require 'yaml'

module CLI
  class << self
    def make_options
      opts = GetoptLong.new(
        [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
        [ '--file', '-f', GetoptLong::REQUIRED_ARGUMENT ]
      )

      options = {}
      options[:config_file] = ""

      opts.each do |opt, arg|
        case opt
        when '--help'
          puts <<-EOF
ruby server.rb ...

-h, --help:
   show help

--file x, -f x:
   Load config from x file
          EOF

        when '--file'
          options[:config_file] = arg.to_s
        end
      end

      options
    end

    DefaultConfig = <<-EOF
---
essential_topics:

health_check_interval: 60
topic_check_interval: 60

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

      if !options[:config_file] || options[:config_file].empty?
        $stderr.puts "Will use default config"
      elsif File.exist?(options[:config_file])
        yaml_content = File.read(options[:config_file])
        config = config.merge(YAML.load(yaml_content))
      else
        $stderr.puts "Could not open #{options[:config_file]}"
      end

      config["essential_topics"] ||= []
      config
    end
  end

  Args = self.make_args
end
