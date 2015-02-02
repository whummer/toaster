module Citac
  module Utils
    module Exec
      def self.run(command, options = {})
        raise_on_failure = options[:raise_on_failure].nil? ? true : options[:raise_on_failure]
        stderr = case options[:stderr] when :forward; '2>&1' when :discard; '2> /dev/null' else '' end

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