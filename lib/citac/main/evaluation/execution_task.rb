require_relative '../../commons/utils/exec'

module Citac
  module Main
    module Evaluation
      class ExecutionTask
        attr_accessor :stepwise

        def initialize(task_description, spec_repository, task_repository, environment_manager, agent_name)
          @spec_repository = spec_repository
          @task_repository = task_repository
          @task_description = task_description
          @stepwise = false
          @environment_manager = environment_manager
          @agent_name = agent_name
        end

        def execute
          spec = @spec_repository.get @task_description.spec_id
          available_operating_systems = @environment_manager.operating_systems spec.type

          spec.operating_systems.each do |os|
            next unless available_operating_systems.any? {|o| o.matches? os}
            puts "Running on #{os}..."

            args = ['spec', 'exec', @task_description.spec_id, os]
            args << '-s' if @stepwise

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