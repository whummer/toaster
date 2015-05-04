module Citac
  module Model
    class TestStepResult
      attr_reader :step, :result, :output

      def initialize(step, result, output)
        @step = step
        @result = result
        @output = output
      end

      def to_s
        "(#{result}) #{step}"
      end
    end
  end
end