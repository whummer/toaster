module Citac
  module Model
    class TestSuiteResult
      attr_reader :test_suite, :test_case_results

      def initialize(test_suite)
        @test_suite = test_suite
        @test_case_results = Hash.new { |h, k| h[k] = [] }
      end

      def add_test_case_result(test_case_result)
        results = @test_case_results[test_case_result.test_case.id]

        unless results
          results = []
          @test_case_results[test_case_result.test_case.id] = results
        end

        results << test_case_result.result
      end

      def overall_case_result(test_case)
        results = @test_case_results[test_case.id] || []

        return :failure if results.include? :failure
        return :success if results.include? :success
        return :unknown
      end

      def overall_suite_result
        @test_suite.test_cases.each do |test_case|
          test_case_result = overall_case_result test_case
          return test_case_result if test_case_result == :failure || test_case_result == :unknown
        end

        return :success
      end
    end
  end
end