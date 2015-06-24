require 'pagerduty'
require 'net/smtp'

class Backtrace
  def initialize(config)
    @config =  {"enabled" => true}.merge(config || {})
    @name = @config["title"]
    @enabled = @config["enabled"]
  end

  def send_traceback(message, &blk)
    if !@enabled
      $stderr.puts "Skipping alerts because sender is disabled"
      return
    end

    begin
      $stderr.puts "Sending traceback..."
      _send(message, &blk)
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace
    end
  end

  def _send(message)
    raise NotImplementedError.new
  end

  def make_json(message)
    Gilmour::Protocol.sanitised_payload message
  end

  def get_description(data)
    description = data.description.empty? ? "Error caught by #{@name}" : data.description
    description[0..1024]
  end
end

class PagerDutySender < Backtrace
  # https://datascale.pagerduty.com/services/PHD8R8Y

  def connection
    if !(defined?(@connection) && @connection)
      @connection = Pagerduty.new(@config["pager_duty_token"])
    end
    @connection
  end

  def _send(body)
    if !@config["pager_duty_token"]
      $stderr.puts "Missing pager_duty_token in Config. Skipping alerts."
      return
    end

    extra = body.extra || {}
    incident_key = extra.topic.empty? ? SecureRandom.hex : extra.topic

    description = get_description extra

    connection.trigger(
      description,
      incident_key: incident_key,
      client:       @name,
      details:      {
        traceback: body.traceback,
        extra: extra
      }
    )

    yield if block_given?
  end
end
