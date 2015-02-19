require_relative '../logging'
require_relative '../model'
require_relative 'colorize'

module Citac
  module Utils
    module Exec
      class RunResult
        attr_reader :output, :exit_code

        def initialize(output, exit_code)
          @output = output
          @exit_code = exit_code
        end
      end

      def self.run(command, options = {})
        raise_on_failure = options[:raise_on_failure].nil? || options[:raise_on_failure]
        stderr = case options[:stderr] when :passthrough; '' when :discard; '2> /dev/null' else '2>&1' end

        args = options[:args] || []
        args = args.map{|a| a.include?(' ') ? "\"#{a}\"" : a}.join(' ')

        cmdline = "#{command} #{args} #{stderr}"

        log_debug 'exec', "Executing command '#{cmdline}'..."
        if options[:stdout] == :passthrough
          output = nil
          system cmdline
        else
          output = `#{cmdline}`
        end

        if $?.exitstatus == 0 || !raise_on_failure
          RunResult.new (output || '').no_colors, $?.exitstatus
        else
          raise "Command '#{cmdline}' failed: #{output || '<no output>'}"
        end
      end
    end
  end
end