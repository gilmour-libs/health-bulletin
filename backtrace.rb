require 'net/smtp'

module Backtrace
  class << self
    def send_traceback(message, config)
      email_body = make_body(message)
      Net::SMTP.start(config[:smtp_host], config[:smtp_port]) do |smtp|
        smtp.send_message email_body, config[:error_from], config[:error_to]
      end
    end

    private

    def make_body(message)
      message
    end
  end
end
