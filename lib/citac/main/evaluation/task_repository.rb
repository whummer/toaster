require 'fileutils'
require_relative '../config'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/utils/serialization'
require_relative 'model'

module Citac
  module Main
    module Evaluation
      class TaskRepository
        def initialize(root_dir)
          raise "Root directory '#{root_dir}' not found." unless Dir.exists? root_dir
          @root_dir = File.absolute_path root_dir
        end

        def assign_next_task(agent_name)
          entries = Dir.entries @root_dir

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
          sync_dirs task_description, get_local_path(task_description)
          sync_spec_status task_description, agent_name
        end

        def sync_spec_status(task_description, agent_name)
          local_path = get_local_path(task_description)

          status_path = File.join local_path, 'evaluation-status.yml'
          Citac::Utils::Serialization.write_to_file TaskStatus.new(Time.now, agent_name), status_path

          sync_dirs local_path, task_description
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
              source_dir = File.join @root_dir, task.dir_name
              target_dir = File.join @root_dir, task.dir_name_running

              puts "Renaming dir from '#{task.dir_name}' to '#{task.dir_name_running}'..."
              File.rename source_dir, target_dir

              return task
            rescue StandardError => e
              puts "Failed to select task '#{task}': #{e}".red
              tasks.delete task
            end
          end

          return nil
        end

        def get_path(task_description)
          path = File.join @root_dir, task_description.dir_name_running
          path[-1] = '' if path[-1] == '/'
          path
        end

        def get_local_path(task_description)
          File.join Citac::Config.spec_dir, "#{task_description.spec_id}.spec"
        end

        def sync_dirs(source_dir, target_dir)
          if source_dir.respond_to? :dir_name
            source_path = get_path(source_dir) + '/'
          else
            source_path = source_dir.to_s
            source_path << '/' unless source_path[-1] == '/'
          end

          if target_dir.respond_to? :dir_name
            target_path = get_path target_dir
          else
            target_path = target_dir.to_s
            target_path[-1] = '' if target_path[-1] == '/'
          end

          Citac::Utils::Exec.run 'rsync', :args => ['-a', '-v', '--delete', source_path, target_path]
        end

        def finalize_task(task_description, task_result, target_name)
          local_path = get_local_path task_description
          source_path = File.join @root_dir, task_description.dir_name_running
          target_path = File.join @root_dir, target_name

          results_path = File.join local_path, 'evalulation-results.yml'
          results = File.exists?(results_path) ? Citac::Utils::Serialization.load_from_file(results_path) : []
          results << task_result
          Citac::Utils::Serialization.write_to_file results, results_path

          results_text_path = File.join local_path, 'evaluation-results.txt'
          File.open(results_text_path, 'a', :encoding => 'UTF-8') {|f| f.puts task_result}

          sync_spec_status task_description, task_result.agent_name
          File.rename source_path, target_path
        end
      end
    end
  end
end