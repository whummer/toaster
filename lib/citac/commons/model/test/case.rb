module Citac
  module Model
    class TestCase
      attr_accessor :id
      attr_reader :type, :resources, :steps

      def executed_resources
        @steps.select { |s| s.type == :exec }.map { |s| s.resource }.to_a
      end

      def name
        case @type
          when :idempotence; "idempotence of #{@resources[0]}"
          when :preservation; "preservation of #{@resources[1]} by #{@resources[0]}"
          else "#{@type} of #{@resources.join ','}"
        end
      end

      def initialize(type, resources, steps = [])
        @type = type
        @resources = resources
        @steps = steps
      end

      def add_exec_step(resource)
        @steps << TestStep.new(:exec, resource)
      end

      def add_assert_step(resource)
        @steps << TestStep.new(:assert, resource)
      end

      def to_s
        "#{name}: #{@steps.map { |s| s.to_s }.to_a.join ', '}"
      end

      def inspect
        "TestCase(#{to_s})"
      end
    end
  end
end