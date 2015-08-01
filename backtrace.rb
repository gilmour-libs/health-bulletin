require 'mash'
require 'pagerduty'
require 'net/smtp'
require './lib/logger'

# Base class for sending all exceptions
class Backtrace
  def initialize(config)
    @config =  { 'enabled' => true }.merge(config || {})
    @name = @config['title']
    @enabled = @config['enabled']
  end

  def send_traceback(message, &blk)
    unless @enabled
      HLogger.warn 'Skipping alerts because sender is disabled'
      return
    end

    begin
      HLogger.debug 'Sending traceback...'
      _send(message, &blk)
    rescue Exception => e
      HLogger.exception e
    end
  end

  def _send(_)
    fail 'Not implemented'
  end

  def make_json(message)
    Gilmour::Protocol.sanitised_payload message
  end

  def get_description(body)
    description = (body.is_a? Mash) ? body.backtrace : ''
    description = "Error caught by #{@name}" if description.empty?
    description[0..1024]
  end

  def get_topic(body)
    topic = (body.is_a? Mash) ? body.topic : ''
    topic ||= SecureRandom.hex
    topic
  end
end

# Pager Duty error sender, derived from Backtrace
class PagerDutySender < Backtrace
  # https://datascale.pagerduty.com/services/PHD8R8Y

  def connection
    unless defined?(@connection) && @connection
      @connection = Pagerduty.new(@config['pager_duty_token'])
    end
    @connection
  end

  def _send(body)
    unless @config['pager_duty_token']
      HLogger.warn 'Missing pager_duty_token in Config. Skipping alerts.'
      return
    end

    begin
      connection.trigger(
        get_description(body),
        incident_key: get_topic(body),
        client:       @name,
        details:      body
      )
    rescue Net::HTTPServerException => error
      HLogger.error "Paging failed. Code #{error.response.code}, Message #{error.response.message} Reason: #{error.response.body} Body: #{body}"
    end

    yield if block_given?
  end
end
