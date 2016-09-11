require_relative '../../commons/utils/exec'

module Citac
  module Integration
    module Sysctl
      def self.get_param(name)
        result = Citac::Utils::Exec.run 'sysctl', :args => ['--values', name], :raise_on_failure => false
        if result.success?
          result.stdout.strip
        else
          nil
        end
      end

      def self.set_param(name, value)
        result = Citac::Utils::Exec.run 'sysctl', :args => ['--write', "#{name}=#{value}"], :raise_on_failure => false
        unless result.success? && result.stderr.strip.size == 0
          raise "Setting kernel parameter '#{name}' to '#{value}' failed: #{result.output}"
        end
      end
    end
  end
end