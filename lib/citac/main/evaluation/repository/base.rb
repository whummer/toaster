require 'fileutils'
require_relative '../../config'
require_relative '../../../commons/utils/exec'
require_relative '../../../commons/utils/colorize'
require_relative '../../../commons/utils/serialization'
require_relative '../model'

module Citac
  module Main
    module Evaluation
      class TaskRepository
        def assign_next_task(agent_name)
          entries = get_directory_list

          alltasks = entries.map{|e| parse_task_description e}.reject{|d| d.nil?}
          tasks = alltasks.reject{|td| td.state == :cancelled || td.state == :failed}
          tasks_by_type = tasks.group_by {|td| TASK_TYPES.index td.type}

          while tasks_by_type.size > 0
            key = tasks_by_type.keys.min
            tasks = tasks_by_type[key]

            task = choose_task tasks
            return task if task

            tasks_by_type.delete key
          end

          other_tasks = alltasks.select{|td| td.state == :cancelled || td.state == :failed}
          task = choose_task other_tasks

          return task
        end

        def load_spec(task_description, agent_name)
          directory_name = task_description.dir_name_running
          local_path = get_local_path(task_description)

          sync_remote_to_local directory_name, local_path
          sync_spec_status task_description, agent_name
        end

        def sync_spec_status(task_description, agent_name)
          local_path = get_local_path(task_description)
          directory_name = task_description.dir_name_running

          status_path = File.join local_path, 'evaluation-status.yml'
          Citac::Utils::Serialization.write_to_file TaskStatus.new(Time.now, agent_name), status_path

          sync_local_to_remote local_path, directory_name
        end

        def return_task(task_description, task_result)
          finalize_task task_description, task_result, task_description.dir_name
        end

        def save_completed_task(task_description, task_result)
          finalize_task task_description, task_result, task_description.dir_name_finished
        end

        def save_failed_task(task_description, task_result)
          finalize_task task_description, task_result, task_description.dir_name_failed
        end

        def cancel_task(task_description, task_result)
          finalize_task task_description, task_result, task_description.dir_name_cancelled
        end

        private

        DIR_EXP = /^(?<state>[a-z]+)__(?<type>[a-z_]+)__(?<name>.+)\.spec$/
        def parse_task_description(dir_name)
          match = DIR_EXP.match dir_name

          if match
            type = match[:type].to_sym
            state = match[:state].to_sym

            return TaskDescription.new type, match[:name], dir_name, state
          elsif dir_name.end_with? '.spec'
            return nil if dir_name.start_with? 'finished__'

            spec_id = dir_name[0..(dir_name.length - 6)]
            return TaskDescription.new TASK_TYPES.first, spec_id, dir_name, :pending
          end

          return nil
        end

        def choose_task(tasks)
          tasks = tasks.dup

          while tasks.size > 0
            task = tasks[rand(tasks.size)]
            begin
              rename_directory task.dir_name, task.dir_name_running

              return task
            rescue StandardError => e
              puts "Failed to select task '#{task}': #{e}".red
              tasks.delete task
            end
          end

          return nil
        end

        def get_local_path(task_description)
          File.join Citac::Config.spec_dir, "#{task_description.spec_id}.spec"
        end

        def finalize_task(task_description, task_result, target_name)
          local_path = get_local_path task_description

          results_path = File.join local_path, 'evalulation-results.yml'
          results = File.exists?(results_path) ? Citac::Utils::Serialization.load_from_file(results_path) : []
          results << task_result
          Citac::Utils::Serialization.write_to_file results, results_path

          results_text_path = File.join local_path, 'evaluation-results.txt'
          File.open(results_text_path, 'a', :encoding => 'UTF-8') {|f| f.puts task_result}

          sync_spec_status task_description, task_result.agent_name

          rename_directory task_description.dir_name_running, target_name
        end
      end
    end
  end
end