require_relative 'colorize'
require_relative '../logging'

module Citac
  module Utils
    class CLIRunner
      def self.run(cli_class)
        $verbose = false

        args = ARGV.dup
        if args.include?('-v') || args.include?('--verbose')
          $verbose = true
          Citac::Logging.level = Logger::DEBUG

          args.delete '-v'
          args.delete '--verbose'
        end

        cli_class.send :start, args
      rescue StandardError => e
        STDERR.puts "#{$prog_name} failed: #{e}".red
        STDERR.puts e.backtrace
        exit 1
      end
    end
  end
end