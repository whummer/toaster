require 'set'
require_relative '../../commons/utils/exec'

module Citac
  module Integration
    module Netstat
      class Port
        attr_reader :protocol, :port_nr

        def initialize(protocol, port_nr)
          @protocol = protocol
          @port_nr = port_nr
        end

        def to_s
          "#{@port_nr}/#{@protocol}"
        end

        def hash
          @port_nr
        end

        def eql?(other)
          @protocol == other.protocol && @port_nr == other.port_nr
        end
        alias_method :==, :eql?
      end

      def self.get_open_ports
        ports = Set.new

        exp = /^(?<protocol>[a-z][a-z0-9]*)\s+[0-9]+\s+[0-9]+\s+[^\s]+:(?<port>[0-9]+)\s/i

        result = Citac::Utils::Exec.run 'netstat', :args => %w(-l -n --inet)
        result.stdout.each_line do |line|
          match = exp.match line.strip
          next unless match

          port = Port.new match[:protocol], match[:port].to_i
          ports << port
        end

        ports.to_a.sort_by{|p| p.port_nr}
      end
    end
  end
end