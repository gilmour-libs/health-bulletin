require 'getoptlong'
require 'yaml'

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
pager_duty_key:
send_backtrace: false
EOF

options = make_options
Config = YAML.load(DefaultConfig)

puts options

if !options[:config_file] || options[:config_file] == ""
  $stderr.puts "Will use default config"
  $stderr.puts DefaultConfig
else
  yaml_content = File.read(options[:config_file])
  Config = Config.merge(YAML.load(yaml_content))
end

Config["essential_topics"] ||= []
