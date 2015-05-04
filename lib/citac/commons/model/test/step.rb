module Citac
  module Model
    class TestStep
      attr_reader :type, :resource

      def initialize(type, resource)
        @type = type
        @resource = resource
      end

      def to_s
        "#{type}(#{resource})"
      end

      def inspect
        "TestStep:#{to_s}"
      end

      def eql?(other)
        @type == other.type && @resource == other.resource
      end

      alias_method :==, :eql?
    end
  end
end
