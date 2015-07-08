require_relative '../../commons/utils/exec'

module Citac
  module Main
    module Evaluation
      class AnalyzationTask
        def initialize(task_description, spec_repository, task_repository, agent_name)
          @spec_repository = spec_repository
          @task_repository = task_repository
          @task_description = task_description
          @agent_name = agent_name
        end

        def execute
          spec = @spec_repository.get @task_description.spec_id
          spec.operating_systems.each do |os|
            args = ['spec', 'analyze', spec.id, os]

            result = Citac::Utils::Exec.run 'citac', :args => args, :output => :passthrough, :raise_on_failure => false
            @task_repository.sync_spec_status @task_description, @agent_name

            return :failure if result.failure?
          end

          return :success_completed
        end
      end
    end
  end
end