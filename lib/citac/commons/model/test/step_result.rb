require 'stringio'

module Citac
  module Model
    class TestStepResult
      attr_reader :step, :result, :output, :execution_time, :change_summary

      def initialize(step, result, output, execution_time, change_summary = nil)
        @step = step
        @result = result
        @output = output
        @change_summary = change_summary
        @execution_time = execution_time
      end

      def assertion_output
        raise "#{self.to_s} is not an assertion" unless @step.type == :assert

        result = StringIO.new

        result.puts @output
        result.puts @change_summary.to_s unless @change_summary.nil? || @change_summary.changes.empty?

        result.string
      end

      def to_s
        "(#{result}) #{step}"
      end
    end
  end
end