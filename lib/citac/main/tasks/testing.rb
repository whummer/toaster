require_relative '../../commons/utils/serialization'

module Citac
  module Main
    module Tasks
      class TestTask
        attr_reader :spec
        attr_accessor :passthrough

        def type
          :test
        end

        def initialize(repository, spec, test_suite, test_case)
          @spec = spec
          @repository = repository
          @test_suite = test_suite
          @test_case = test_case
          @passthrough = false
        end

        def additional_args
          result = []
          result << '-p' if @passthrough
          result
        end

        def before_execution(dir, operating_system)
          path = File.join dir, 'test_case.yml'
          Citac::Utils::Serialization.write_to_file @test_case, path
        end

        def after_execution(dir, operating_system, result, run)
          raise "Testing #{@spec} (test suite #{@test_suite}, test case #{@test_case}) failed: #{result.output}" if result.failure?

          path = File.join dir, 'test_case_result.yml'
          test_case_result = Citac::Utils::Serialization.load_from_file path

          puts
          puts "Test case result: #{test_case_result.colored_result}"

          @repository.save_test_case_result @spec, operating_system, @test_suite, test_case_result

          test_case_result
        end
      end
    end
  end
end