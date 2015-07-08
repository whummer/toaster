require_relative '../../commons/utils/exec'
require_relative 'execution_task'
require_relative 'analyzation_task'
require_relative 'generation_task'
require_relative 'test_task'
require_relative 'model'

module Citac
  module Main
    module Evaluation
      class EvaluationAgent
        RESULT_MAPPING = {:success_partial => 0, :success_completed => 1, :failure => 2, :error => 3, :cancelled => 4}
        EXIT_CODE_MAPPING = RESULT_MAPPING.invert

        attr_accessor :name

        def initialize(task_repository, spec_repository, environment_manager)
          @task_repository = task_repository
          @spec_repository = spec_repository
          @environment_manager = environment_manager

          @name = Citac::Utils::Exec.run('hostname', :args => ['--fqdn']).output.strip
          puts "Agent Name: #{@name}"
        end

        def run
          puts 'Starting agent...'
          while true
            begin
              run_once
            rescue Interrupt
              puts 'Shutting down...'
              break
            rescue Exception => e
              puts "Run failed: #{e.message}".red
              puts e.backtrace
            end
          end
        end

        def run_once
          puts "[#{Time.now}] Getting next task..."
          task_description = @task_repository.assign_next_task @name

          if task_description
            start_time = Time.now
            run_result = Citac::Utils::Exec.fork :output => :passthrough do
              result = run_task task_description
              exit! RESULT_MAPPING[result]
            end
            end_time = Time.now

            result = EXIT_CODE_MAPPING[run_result.exit_code]
            task_result = TaskResult.new result, @name, start_time, end_time, run_result.output

            case result
              when :success_partial
                @task_repository.return_task task_description, task_result
              when :success_completed
                @task_repository.save_completed_task task_description, task_result
              when :failure
                @task_repository.save_failed_task task_description, task_result
              when :error
                @task_repository.save_failed_task task_description, task_result
              when :cancelled
                @task_repository.return_task task_description, task_result
              else
                raise "Unknown result: #{result}"
            end
          end
        end

        private

        def run_task(task_description)
          start = Time.now

          puts '============================================================='.yellow
          puts '============================================================='.yellow
          puts "Running #{task_description}...".yellow
          puts
          puts "Agent: #{@name}".yellow
          puts "Start: #{start}".yellow
          puts '============================================================='.yellow
          puts '============================================================='.yellow
          puts

          begin
            puts "[#{Time.now}] Fetching configuration specification..."
            @task_repository.load_spec task_description, @name

            puts "[#{Time.now}] Executing task..."
            task = create_task task_description
            result = task.execute
          rescue Interrupt
            puts "Execution of #{task_description} interrupted.".yellow
            result = :cancelled
          rescue StandardError => e
            puts "Execution of #{task_description} failed: #{e.message}".red
            puts e.backtrace
            result = :error
          end

          finish = Time.now
          if result.to_s.start_with? 'success'
            formatted_result = result.to_s.upcase.green
          else
            formatted_result = result.to_s.upcase.red
          end

          puts
          puts '============================================================='.yellow
          puts '============================================================='.yellow
          puts "Finished #{task_description}!".yellow
          puts
          puts "End:    #{finish}".yellow
          puts "Time:   #{finish - start} seconds".yellow
          puts "#{'Result: '.yellow}#{formatted_result}"
          puts '============================================================='.yellow
          puts '============================================================='.yellow

          return result
        end

        def create_task(task_description)
          case task_description.type
            when :execute_regular
              task = ExecutionTask.new task_description, @spec_repository, @task_repository, @environment_manager, @name
              task.stepwise = false
            when :execute_stepwise
              task = ExecutionTask.new task_description, @spec_repository, @task_repository, @environment_manager, @name
              task.stepwise = true
            when :analyze
              task = AnalyzationTask.new task_description, @spec_repository, @task_repository, @name
            when :analyze
              task = AnalyzationTask.new task_description, @spec_repository, @task_repository, @name
            when :generate_base
              task = GenerationTask.new task_description, @spec_repository, @task_repository, :base, @name
            when :generate_stg
              task = GenerationTask.new task_description, @spec_repository, @task_repository, :stg, @name
            when :test_base
              task = TestTask.new task_description, @spec_repository, @task_repository, :base, @name
            when :test_stg
              task = TestTask.new task_description, @spec_repository, @task_repository, :stg, @name
            else
              raise "Unknown task type: #{task_description.type}"
          end

          task
        end
      end
    end
  end
end