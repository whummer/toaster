module Citac
  module Utils
    module Exec
      def self.run(command, options = {})
        raise_on_failure = options[:raise_on_failure].nil? ? true : options[:raise_on_failure]
        stderr = case options[:stderr] when :passthrough; '' when :discard; '2> /dev/null' else '2>&1' end

        output = `#{command} #{stderr}`

        if $?.exitstatus == 0 || !raise_on_failure
          output
        else
          raise "Command '#{command}' failed: #{output}"
        end
      end
    end
  end
end