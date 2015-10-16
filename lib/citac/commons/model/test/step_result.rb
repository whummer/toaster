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

      def to_s
        "(#{result}) #{step}"
      end
    end
  end
end