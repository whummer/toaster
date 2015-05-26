module Citac
  module Model
    class Property
      attr_reader :type, :resources

      def initialize(type, resources)
        @type = type
        @resources = resources
      end

      def to_s
        case @type
          when :idempotence;  "idempotence  of #{@resources[0]}"
          when :preservation; "preservation of #{@resources[1]} by #{@resources[0]}"
          else "#{@type} of #{@resources.join ','}"
        end
      end

      def hash
        [@type, @resources].hash
      end

      def eql?(other)
        @type == other.type && @resources == other.resource
      end

      alias_method :==, :eql?
    end
  end
end
