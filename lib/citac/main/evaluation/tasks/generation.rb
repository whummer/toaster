require_relative '../../../commons/utils/exec'
require_relative 'base'

module Citac
  module Main
    module Evaluation
      class GenerationTask < EvaluationTask
        attr_accessor :additional_args

        def initialize(task_description, spec_repository, task_repository, environment_manager, agent_name, type)
          super task_description, spec_repository, task_repository, environment_manager, agent_name

          @type = type
          @additional_args = []
        end

        def fulfilled?(spec, operating_system)
          spec_repository.test_suites(spec, operating_system).any? {|s| s.name.include? @type.to_s}
        rescue
          return false
        end

        def execute_os(spec, operating_system)
          args = ['test', 'gen', spec.id, operating_system, '-t', @type]
          args += @additional_args

          result = Citac::Utils::Exec.run 'citac', :args => args, :output => :passthrough, :raise_on_failure => false
          result.success? ? :success_completed : :failure
        end
      end
    end
  end
end