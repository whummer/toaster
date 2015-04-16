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


    class TestStepResult
      attr_reader :step, :result, :output

      def initialize(step, result, output)
        @step = step
        @result = result
        @output = output
      end
    end

    class TestCase
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

    class TestCaseResult
      attr_reader :test_case, :step_results

      def success?
        @success
      end

      def initialize(test_case)
        @test_case = test_case
        @step_results = []
      end

      def add_step_result(step, success, output)
        raise 'All results already added' if @step_results.size == @test_case.steps.size

        expected_step = @test_case.steps[@step_results.size]
        raise "Cannot add step result because '#{expected_step.name}' is expected instead of '#{step.name}'" unless step == expected_step

        result = success ? :success : :failure
        @step_results << TestStepResult.new(step, result, output)
      end

      def finish
        while @step_results.size < @test_case.steps.size
          @step_results << TestStepResult.new(@test_case.steps[@step_results.size], :skipped, nil)
        end

        @success = @step_results.last.result == :success
      end
    end
  end
end