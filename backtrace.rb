require 'pagerduty'
require 'net/smtp'

module Backtrace
  class << self
    # https://datascale.pagerduty.com/services/PHD8R8Y
    # TODO: Please read this value from Command line or conf file.
    PAGERDUTY_SERVICE_KEY = '3cf9ee19d2654c0e8c4ace1184ca8ac9'

    def connection
      if !(defined?(@@connection) && @@connection)
        @@connection = Pagerduty.new(PAGERDUTY_SERVICE_KEY)
      end
      @@connection
    end

    def send_traceback(message, config)
      #data, sender = Gilmour::Protocol.parse_request(message)
      body = message.body
      #Net::SMTP.start(config[:smtp_host], config[:smtp_port]) do |smtp|
      #  smtp.send_message email_body, config[:error_from], config[:error_to]
      #end

      extra = body.extra || {}
      description = extra.description.empty? ? "Error with Backend Manager" : extra.description

      incident_key = extra.topic.empty? ? SecureRandom.hex : extra.topic

      connection.trigger(
        description[0..1024],
        incident_key: incident_key,
        client:       "Health Monitor",
        details:      {
          traceback: body.traceback,
          extra: extra
        }
      )
    end

    private

    def make_json(message)
      Gilmour::Protocol.sanitised_payload message
    end
  end
end
