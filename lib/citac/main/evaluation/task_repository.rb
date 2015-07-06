require 'fileutils'
require_relative '../config'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/colorize'
require_relative 'model'

module Citac
  module Main
    module Evaluation
      class TaskRepository
        def initialize(root_dir)
          raise "Root directory '#{root_dir}' not found." unless Dir.exists? root_dir
          @root_dir = File.absolute_path root_dir
        end

        def get_next_task
          pending_dir = File.join @root_dir, 'pending'

          TASK_TYPES.each do |task_type|
            dir = File.join pending_dir, task_type.to_s
            next unless Dir.exists? dir

            spec_ids = Dir.entries(dir)
            spec_ids.delete '.'
            spec_ids.delete '..'

            next if spec_ids.empty?

            while spec_ids.size > 0
              spec_id = spec_ids[rand(spec_ids.size)]
              begin
                inprogress_dir = File.join @root_dir, 'inprogress', task_type.to_s
                FileUtils.makedirs inprogress_dir

                source_dir = File.join dir, spec_id
                target_dir = File.join inprogress_dir, spec_id

                File.rename source_dir, target_dir
                write_status target_dir

                return TaskDescription.new task_type, spec_id
              rescue StandardError => e
                puts "Failed to select spec '#{spec_id}': #{e}".red
                spec_ids.delete spec_id
              end
            end
          end

          return nil
        end

        def load_spec(task_description)
          source_dir = File.join @root_dir, 'inprogress', task_description.type.to_s, task_description.spec_id
          source_dir[-1] = '' if source_dir[-1] == '/' #remove trailing slash

          dest_dir = Citac::Config.spec_dir

          Citac::Utils::Exec.run 'rsync', :args => ['-a', '-v', '--delete', source_dir, dest_dir]
          write_status source_dir
        end

        def sync_spec_progress(task_description)
          dest_dir = File.join @root_dir, 'inprogress', task_description.type.to_s, task_description.spec_id
          source_dir = File.join Citac::Config.spec_dir, task_description.spec_id
          source_dir += '/' unless source_dir[-1] == '/'

          Citac::Utils::Exec.run 'rsync', :args => ['-a', '-v', '--delete', source_dir, dest_dir]
          write_status dest_dir
        end

        def save_completed_task(task_description)
          spec_dir = File.join @root_dir, 'inprogress', task_description.type.to_s, task_description.spec_id

          type_index = TASK_TYPES.index(task_description.type)
          if type_index + 1 < TASK_TYPES.size
            next_type = TASK_TYPES[type_index + 1]
            target_dir = File.join @root_dir, 'pending', next_type.to_s
          else
            target_dir = File.join @root_dir, 'finished'
          end
          FileUtils.makedirs target_dir

          File.rename spec_dir, File.join(target_dir, task_description.spec_id)
        end

        def save_failed_task(task_description)
          spec_dir = File.join @root_dir, 'inprogress', task_description.type.to_s, task_description.spec_id

          target_dir = File.join @root_dir, 'failed'
          FileUtils.makedirs target_dir

          File.rename spec_dir, File.join(target_dir, task_description.spec_id)
        end

        def cancel_task(task_description)
          source_dir = File.join @root_dir, 'inprogress', task_description.type.to_s, task_description.spec_id

          cancelled_dir = File.join @root_dir, 'cancelled'
          FileUtils.makedirs cancelled_dir

          target_dir = File.join(cancelled_dir, task_description.spec_id)
          File.rename source_dir, target_dir
          File.delete File.join(target_dir, 'eval-status.txt')
        end

        private

        def write_status(dir)
          path = File.join dir, 'eval-status.txt'

          status = "Agent: HUGO\n" #TODO agent name
          status << "Last Update: #{Time.now}\n"

          IO.write path, status, :encoding => 'UTF-8'
        end
      end
    end
  end
end