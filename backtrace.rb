require "mash"
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

  def get_description(description)
    description ||= "Error caught by #{@name}"
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

    extra = body.extra
    description = incident_key = ''

    if not extra.nil?
      incident_key = extra.topic.empty? ? SecureRandom.hex : extra.topic
      description = extra.description
    end

    incident_key ||= body.topic
    description ||= get_description(body.description)

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
