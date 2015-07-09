require_relative '../../../commons/utils/exec'
require_relative 'base'

module Citac
  module Main
    module Evaluation
      class ExecutionTask < EvaluationTask
        attr_accessor :stepwise

        def initialize(task_description, spec_repository, task_repository, environment_manager, agent_name)
          super
          @stepwise = false
        end

        def fulfilled?(spec, operating_system)
          expected_action = @stepwise ? 'exec_stepwise' : 'exec'
          spec_repository.runs(spec).
              select{|r| r.operating_system == operating_system}.
              select{|r| r.action == expected_action}.
              any?{|r| r.exit_code == 0}
        rescue
          return false
        end

        def execute_os(spec, operating_system)
          args = ['spec', 'exec', spec.id, operating_system]
          args << '-s' if @stepwise

          result = Citac::Utils::Exec.run 'citac', :args => args, :output => :passthrough, :raise_on_failure => false
          result.success? ? :success_completed : :failure
        end
      end
    end
  end
end