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
    description = body.description
    incident_key = body.topic

    if not extra.nil?
      if extra.topic != ""
        incident_key = extra.topic
      end

      if extra.description != ""
        description = extra.description
      end
    end

    incident_key ||= SecureRandom.hex
    description = get_description description

    extra['trceback'] = body.traceback

    connection.trigger(
      description,
      incident_key: incident_key,
      client:       @name,
      details:      extra
    )

    yield if block_given?
  end
end
