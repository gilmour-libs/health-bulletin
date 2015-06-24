require 'logger'
require_relative 'cli'


module HealthLogger
  LoggerLevels = {
    fatal: Logger::FATAL,
    error: Logger::ERROR,
    warn: Logger::WARN,
    info: Logger::INFO,
    debug: Logger::DEBUG
  }

  def self.make(level)
    logger = Logger.new(STDERR)
    logger.level = LoggerLevels[level] || Logger::WARN

    logger.class.send("define_method", "exception", Proc.new { |e|
      self.error e.message
      e.backtrace.each do |line|
        self.error line
      end
    })

    logger
  end
end


HLogger = HealthLogger.make(CLI::Args['log_level'].to_sym)
