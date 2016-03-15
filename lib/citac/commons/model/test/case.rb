require 'stringio'

module Citac
  module Model
    class TestCase
      attr_accessor :id
      attr_reader :steps

      def executed_resources
        @steps.select { |s| s.type == :exec }.map { |s| s.resource }.to_a
      end

      def execs
        @steps.select{|s| s.type == :exec}
      end

      def asserts
        @steps.select{|s| s.type == :assert}
      end

      def initialize(steps = [])
        @id = nil
        @steps = steps
      end

      def add_exec_step(resource)
        @steps << TestStep.new(:exec, resource)
      end

      def add_assert_step(resource, property)
        @steps << TestStep.new(:assert, resource, property)
      end

      def reduce
        index = @steps.rindex {|s| s.type == :assert} || -1
        index += 1

        @steps.slice! index, @steps.size - index
      end

      def name; "Test Case #{@id}"; end
      def to_s
        sb = StringIO.new
        sb.puts "#{name}: #{@steps.map{|s| s.to_s}.join ', '}"
        asserts.each do |assert_step|
          sb.puts " - #{assert_step.property}"
        end

        sb.string
      end
    end
  end
end