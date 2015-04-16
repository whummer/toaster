require_relative '../../commons/utils/serialization'

module Citac
  module Main
    module Tasks
      class TestTask
        attr_reader :spec

        def type
          :test
        end

        def initialize(repository, spec, test_case)
          @spec = spec
          @repository = repository
          @test_case = test_case
        end

        def before_execution(dir, operating_system)
          path = File.join dir, 'test_case.yml'
          Citac::Utils::Serialization.write_to_file @test_case, path
        end

        def after_execution(dir, operating_system, result, run)
          path = File.join dir, 'test_case_result.yml'
          test_case_result = Citac::Utils::Serialization.load_from_file path

          status = test_case_result.success? ? 'SUCCESS'.green : 'FAIL'.red
          puts "Test case result: #{status}"

          #TODO save test case result to repository
        end
      end
    end
  end
end