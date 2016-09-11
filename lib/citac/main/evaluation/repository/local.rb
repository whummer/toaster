require 'fileutils'
require_relative '../../config'
require_relative '../../../commons/utils/exec'
require_relative '../../../commons/utils/colorize'
require_relative '../../../commons/utils/serialization'
require_relative '../model'
require_relative 'base'

module Citac
  module Main
    module Evaluation
      class LocalTaskRepository < TaskRepository
        def initialize(root_dir)
          raise "Root directory '#{root_dir}' not found." unless Dir.exists? root_dir
          @root_dir = File.absolute_path root_dir
        end

        def get_directory_list
          Dir.entries @root_dir
        end

        def rename_directory(old_name, new_name)
          puts "Renaming dir from '#{old_name}' to '#{new_name}'..."

          source_dir = File.join @root_dir, old_name
          target_dir = File.join @root_dir, new_name

          File.rename source_dir, target_dir
        end

        def sync_remote_to_local(directory_name, local_path)
          source_path = File.join @root_dir, directory_name
          sync_dirs source_path, local_path
        end

        def sync_local_to_remote(local_path, directory_name)
          target_path = File.join @root_dir, directory_name
          sync_dirs local_path, target_path
        end

        def sync_dirs(source_dir, target_dir)
          source_path = source_dir.to_s
          source_path << '/' unless source_path[-1] == '/'

          target_path = target_dir.to_s
          target_path[-1] = '' if target_path[-1] == '/'

          Citac::Utils::Exec.run 'rsync', :args => ['-a', '-v', '--delete', source_path, target_path]
        end
      end
    end
  end
end