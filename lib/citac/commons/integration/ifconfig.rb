require_relative '../../commons/utils/exec'

module Citac
  module Integration
    module Ifconfig
      INTERFACE_EXP = /^(?<name>[a-z][a-z0-9]*)((:)|(\s))(?<info>.*)$/i
      COUNTER_EXP = /((R|T)X ((bytes)|(packets)))|(collisions)/i

      def self.get_interfaces
        interfaces = Hash.new {|h,k| h[k] = [] }

        current_interface = nil
        result = Citac::Utils::Exec.run 'ifconfig', :args => ['-a']
        result.stdout.each_line do |line|
          match = INTERFACE_EXP.match line
          if match
            current_interface = match[:name]
            line = match[:info].strip
          end

          line = line.strip
          next if line.size == 0 || line =~ COUNTER_EXP

          raise "Unable to associate line '#{line}' to a network interface" unless current_interface
          interfaces[current_interface] << line
        end

        interfaces
      end
    end
  end
end