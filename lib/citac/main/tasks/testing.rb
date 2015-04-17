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

        def initialize(repository, spec, test_case)
          @spec = spec
          @repository = repository
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
          path = File.join dir, 'test_case_result.yml'
          test_case_result = Citac::Utils::Serialization.load_from_file path

          status = test_case_result.success? ? 'SUCCESS'.green : 'FAILURE'.red

          puts
          puts "Test case result: #{status}"

          @repository.save_test_case_result @spec, test_case_result

          test_case_result
        end
      end
    end
  end
end