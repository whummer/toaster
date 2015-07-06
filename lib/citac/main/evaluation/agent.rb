require_relative '../../commons/utils/exec'
require_relative 'execution_task'
require_relative 'analyzation_task'
require_relative 'generation_task'
require_relative 'test_task'

module Citac
  module Main
    module Evaluation
      class EvaluationAgent
        def initialize(task_repository, spec_repository)
          @task_repository = task_repository
          @spec_repository = spec_repository
        end

        def run
          while true
            begin
              success = run_once
              sleep 30 unless success
            rescue Interrupt
              return
            rescue StandardError => e
              puts "Error: #{e}"
            end
          end
        rescue Interrupt
          puts 'Shutting down...'
        end

        def run_once
          puts 'Getting next task...'
          task_description = @task_repository.get_next_task

          if task_description
            puts "Running task #{task_description}...".yellow

            @task_repository.load_spec task_description
            task = create_task task_description
            success = task.execute

            puts "Result: #{success ? 'SUCCESS'.green : 'FAILURE'.red}"
            if success
              @task_repository.save_completed_task task_description
            else
              @task_repository.save_failed_task task_description
            end

            return true
          else
            puts 'No task found.'.yellow
            return false
          end
        rescue StandardError => e
          puts "Task execution failed: #{e}"

          if task_description
            puts 'Cancelling task...'.red
            @task_repository.cancel_task task_description
          end

          return false
        end

        private

        def create_task(task_description)
          case task_description.type
            when :execute_regular
              task = ExecutionTask.new task_description, @spec_repository, @task_repository
              task.stepwise = false
            when :execute_stepwise
              task = ExecutionTask.new task_description, @spec_repository, @task_repository
              task.stepwise = true
            when :analyze
              task = AnalyzationTask.new task_description, @spec_repository, @task_repository
            when :analyze
              task = AnalyzationTask.new task_description, @spec_repository, @task_repository
            when :generate_base
              task = GenerationTask.new task_description, @spec_repository, @task_repository, :base
            when :generate_stg
              task = GenerationTask.new task_description, @spec_repository, @task_repository, :stg
            when :test_base
              task = TestTask.new task_description, @spec_repository, @task_repository, :base
            when :test_stg
              task = TestTask.new task_description, @spec_repository, @task_repository, :stg
            else
              raise "Unknown task type: #{task_description.type}"
          end

          task
        end
      end
    end
  end
end