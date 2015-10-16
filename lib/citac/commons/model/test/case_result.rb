require 'stringio'
require_relative 'step_result'
require_relative '../../../../../lib/citac/commons/utils/colorize'

module Citac
  module Model
    class TestCaseResult
      attr_reader :test_case, :step_results

      def result
        last = @step_results.reverse.find{|r| r.result != :skipped}
        return :failure unless last

        return :failure if @step_results.find{|r| r.step.type == :assert && r.result == :failure}
        return :success if last.result == :success
        return :aborted if last.result == :failure

        return :unknown
      end

      def colored_result
        case result
          when :success
            return 'SUCCESS'.green
          when :failure
            return 'FAILURE'.red
          when :aborted
            return 'ABORTED'.yellow
          else
            return result.to_s.upcase
        end
      end

      def success?
        @success
      end

      def initialize(test_case)
        @test_case = test_case
        @step_results = []
      end

      def add_step_result(step, success, output, change_summary = nil)
        raise 'All results already added' if @step_results.size == @test_case.steps.size

        expected_step = @test_case.steps[@step_results.size]
        raise "Cannot add step result because '#{expected_step.name}' is expected instead of '#{step.name}'" unless step == expected_step

        result = success ? :success : :failure
        @step_results << TestStepResult.new(step, result, output, change_summary)
      end

      def finish
        while @step_results.size < @test_case.steps.size
          @step_results << TestStepResult.new(@test_case.steps[@step_results.size], :skipped, nil)
        end

        @success = @step_results.last.result == :success
      end

      def to_s
        result = StringIO.new
        result.puts '====================================================================='
        result.puts 'Test Case Result - Overview'
        result.puts '====================================================================='
        result.puts
        result.puts "Test Case: #{@test_case.name}"
        result.puts "Result:    #{self.result.to_s.upcase}"
        result.puts
        result.puts 'Steps:'
        @step_results.each_with_index {|s, i| result.puts "  #{i + 1}. #{s}"}
        result.puts

        @step_results.each_with_index do |step_result, index|
          result.puts '====================================================================='
          result.puts "#{index + 1}. #{step_result.step}"
          result.puts '====================================================================='
          result.puts
          result.puts "Step result: #{step_result.result}"
          unless step_result.result == :skipped
            result.puts
            result.puts '############## OUTPUT START ##############'
            result.puts step_result.output
            result.puts '##############  OUTPUT END  ##############'
          end

          if step_result.change_summary
            result.puts
            result.puts '########## CHANGE SUMMARY START ##########'
            result.puts step_result.change_summary
            result.puts '##########  CHANGE SUMMARY END  ##########'
          end
          result.puts
        end

        result.string
      end
    end
  end
end