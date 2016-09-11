module Citac
  module Model
    class TestSuiteResult
      attr_reader :test_suite, :test_case_results

      def pending_test_cases
        @test_suite.test_cases.map{|c| [c, overall_case_result(c)]}.select{|_, r| r == :unknown}.map{|r, _| r}
      end

      def aborted_test_cases
        @test_suite.test_cases.select{|c| (@test_case_results[c.id] || []).all?{|r| r == :aborted}}
      end

      def failed_test_cases
        @test_suite.test_cases.map{|c| [c, overall_case_result(c)]}.select{|_, r| r == :failure}.map{|r, _| r}
      end

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