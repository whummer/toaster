module Citac
  module Main
    module Evaluation
      class EvaluationTask
        attr_reader :environment_manager, :spec_repository, :task_repository, :agent_name, :task_description

        def initialize(task_description, spec_repository, task_repository, environment_manager, agent_name)
          @spec_repository = spec_repository
          @task_repository = task_repository
          @task_description = task_description
          @environment_manager = environment_manager
          @agent_name = agent_name
        end

        def execute
          spec = @spec_repository.get @task_description.spec_id
          available_operating_systems = @environment_manager.operating_systems spec.type

          pending_operating_systems = []

          available_operating_systems.each do |available_os|
            matching_os = spec.operating_systems.find{|compatible_os| available_os.matches? compatible_os}
            pending_operating_systems << matching_os if matching_os && !fulfilled?(spec, matching_os)
          end

          return :success_completed if pending_operating_systems.empty?

          pending_os = pending_operating_systems.first
          begin
            puts "Running on #{pending_os}..."
            result = execute_os spec, pending_os

            puts 'Syncing spec status...'
            @task_repository.sync_spec_status @task_description, @agent_name

            if result == :success_completed && pending_operating_systems.size > 1
              return :success_partial
            else
              return result
            end
          rescue StandardError => e
            puts "Task failed: #{e.message}"
            return :failure
          end
        end
      end
    end
  end
end