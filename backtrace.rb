require 'pagerduty'
require 'net/smtp'
require './lib/logger'

class Backtrace
  def initialize(config)
    @config =  {"enabled" => true}.merge(config || {})
    @name = @config["title"]
    @enabled = @config["enabled"]
  end

  def send_traceback(message, &blk)
    if !@enabled
      HLogger.warn "Skipping alerts because sender is disabled"
      return
    end

    begin
      HLogger.debug "Sending traceback..."
      _send(message, &blk)
    rescue Exception => e
      HLogger.exception e
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
      HLogger.warn "Missing pager_duty_token in Config. Skipping alerts."
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
