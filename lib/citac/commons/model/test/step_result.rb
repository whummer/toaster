module Citac
  module Model
    class TestStepResult
      attr_reader :step, :result, :output, :change_summary

      def initialize(step, result, output, change_summary = nil)
        @step = step
        @result = result
        @output = output
        @change_summary = change_summary
      end

      def to_s
        "(#{result}) #{step}"
      end
    end
  end
end