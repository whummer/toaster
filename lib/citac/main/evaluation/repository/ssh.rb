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
      #TODO implement retries

      class SshTaskRepository < TaskRepository
        def initialize(host, user, root_dir)
          @host = host
          @user = user
          @root_dir = root_dir
        end

        def get_directory_list
          result = Citac::Utils::Exec.run 'ssh', :args => ["#{@user}@#{@host}", 'ls', '-1', '-a', @root_dir]
          result.stdout.lines.map{|l| l.strip}.select{|l| l.length > 0}.to_a
        end

        def rename_directory(old_name, new_name)
          puts "Renaming dir from '#{old_name}' to '#{new_name}'..."

          source_dir = File.join @root_dir, old_name
          target_dir = File.join @root_dir, new_name

          Citac::Utils::Exec.run 'ssh', :args => ["#{@user}@#{@host}", 'mv', source_dir, target_dir]
        end

        def sync_remote_to_local(directory_name, local_path)
          puts "Syncing remote #{directory_name} to local #{local_path}..."

          source_path = "#{@user}@#{@host}:#{File.join(@root_dir, directory_name)}"
          sync_dirs source_path, local_path
        end

        def sync_local_to_remote(local_path, directory_name)
          puts "Syncing local #{local_path} to remote #{directory_name}..."

          target_path = "#{@user}@#{@host}:#{File.join(@root_dir, directory_name)}"
          sync_dirs local_path, target_path
        end

        def sync_dirs(source_dir, target_dir)
          source_path = source_dir.to_s
          source_path << '/' unless source_path[-1] == '/'

          target_path = target_dir.to_s
          target_path[-1] = '' if target_path[-1] == '/'

          Citac::Utils::Exec.run 'rsync', :args => ['-a', '-z', '-v', '--delete', '-e', 'ssh', source_path, target_path]
        end
      end
    end
  end
end