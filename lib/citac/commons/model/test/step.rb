module Citac
  module Model
    class TestStep
      attr_reader :type, :resource, :property

      def initialize(type, resource, property = nil)
        @type = type
        @resource = resource
        @property = property
      end

      def to_s
        "#{type}(#{resource})"
      end

      def inspect
        "TestStep:#{to_s}"
      end

      def hash
        [@type, @resource].hash
      end

      def eql?(other)
        @type == other.type && @resource == other.resource
      end

      alias_method :==, :eql?
    end
  end
end
