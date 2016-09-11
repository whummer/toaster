require 'logger'

module Citac
  module Logging
    class Log
      attr_accessor :logger

      def initialize(logger, name)
        @logger = logger
        @name = name
      end

      def debug(msg, e = nil)
        fmsg = format_msg msg, e
        @logger.debug(@name) { fmsg }
      end

      def info(msg, e = nil)
        fmsg = format_msg msg, e
        @logger.info(@name) { fmsg }
      end

      def warn(msg, e = nil)
        fmsg = format_msg msg, e
        @logger.warn(@name) { fmsg }
      end

      def error(msg, e = nil)
        fmsg = format_msg msg, e, true
        @logger.error(@name) { fmsg }
      end

      def fatal(msg, e = nil)
        fmsg = format_msg msg, e, true
        @logger.fatal(@name) { fmsg }
      end

      private

      def format_msg(msg, e, full_backtrace = false)
        if e
          msg += ": #{e}\n"
          if full_backtrace
            msg += e.backtrace.join("\n")
          else
            msg += e.backtrace.inspect
          end
        end

        msg
      end
    end

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::WARN
    @logger.formatter = proc { |severity, datetime, progname, msg|
      "#{severity.ljust(5)} #{datetime.strftime('%H:%M:%S.%L')} [#{progname}]: #{msg}#{$/}"
    }

    @logs = Hash.new {|h, k| h[k] = Log.new @logger, k }

    def self.log_file=(logdev)
      level = @logger.level
      @logger = Logger.new logdev
      @logger.level = level

      @logs.each_value do |log|
        log.logger = @logger
      end
    end

    def self.level=(level)
      @logger.level = level
    end

    def self.get(name)
      @logs[name]
    end
  end
end

def log_debug(name, msg, e = nil)
  log = Citac::Logging.get name
  log.debug msg, e
end

def log_info(name, msg, e = nil)
  log = Citac::Logging.get name
  log.info msg, e
end

def log_warn(name, msg, e = nil)
  log = Citac::Logging.get name
  log.warn msg, e
end

def log_error(name, msg, e = nil)
  log = Citac::Logging.get name
  log.error msg, e
end

def log_fatal(name, msg, e = nil)
  log = Citac::Logging.get name
  log.fatal msg, e
end