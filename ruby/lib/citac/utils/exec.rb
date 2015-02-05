require_relative '../logging'

module Citac
  module Utils
    module Exec
      def self.run(command, options = {})
        raise_on_failure = options[:raise_on_failure].nil? ? true : options[:raise_on_failure]
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
          output
        else
          raise "Command '#{cmdline}' failed: #{output || '<no output>'}"
        end
      end
    end
  end
end