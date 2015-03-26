require 'securerandom'
require_relative 'containers'
require_relative 'images'
require_relative '../utils/file_access_tracking'
require_relative '../utils/md5'
require_relative '../utils/system'
require_relative '../logging'

module Citac
  module Docker
    module ChangeTracker
      class << self
        def track_changes(command, options = {})
          snapshot_image = create_snapshot_image
          modified_files = Citac::Utils::FileAccessTracking.track_modified_files command, options

          pre_files = get_pre_existing_files snapshot_image, modified_files
          post_files = get_post_existing_files modified_files

          new_files = post_files.reject{|f| pre_files.include? f}.to_a
          unless new_files.empty?
            puts 'New files:'
            new_files.each do |new_file|
              puts " - #{new_file}"
            end
          end

          changed_files = post_files.select{|f| pre_files.include? f}.to_a
          unless changed_files.empty?
            pre_sizes = get_pre_file_sizes snapshot_image, changed_files
            post_sizes = get_post_file_sizes changed_files

            same_size_files = changed_files.select{|f| pre_sizes[f] == post_sizes[f]}
            different_size_files = changed_files - same_size_files

            pre_hashes = get_pre_hashes snapshot_image, same_size_files
            post_hashes = get_post_hashes same_size_files

            same_hash_files = same_size_files.select{|f| pre_hashes[f] == post_hashes[f]}.to_a
            different_hash_files = same_size_files - same_hash_files

            touched_files = same_hash_files
            changed_files = different_size_files + different_hash_files

            unless changed_files.empty?
              puts 'Changed files:'
              changed_files.each do |changed_file|
                puts " - #{changed_file}"
              end
            end

            unless touched_files.empty?
              puts 'Touched files (content same, but written to):'
              touched_files.each do |touched_file|
                puts " - #{touched_file}"
              end
            end
          end

          deleted_files = pre_files.reject{|f| post_files.include? f}.to_a
          unless deleted_files.empty?
            puts 'Deleted files:'
            deleted_files.each do |deleted_file|
              puts " - #{deleted_file}"
            end
          end

          temp_files = modified_files.reject{|f| pre_files.include? f}.reject{|f| post_files.include? f}.to_a
          unless temp_files.empty?
            puts 'Temporary files (created and deleted):'
            temp_files.each do |temporary_file|
              puts " - #{temporary_file}"
            end
          end
        ensure
          remove_snapshot_image snapshot_image
        end

        private

        def get_pre_existing_files(snapshot_image, modified_files)
          modified_directories = Hash.new {|h, k| h[k] = []}
          modified_files.each do |modified_file|
            dir = File.dirname modified_file
            name = File.basename modified_file

            modified_directories[dir] << name
          end

          existing_files = []
          modified_directories.each_pair do |modified_directory, files|
            result = Docker.run snapshot_image, ['ls', '-1', '-a', modified_directory], :raise_on_failure => false
            if result.success?
              result.output.each_line do |line|
                existing_file = line.strip
                if files.include? existing_file
                  existing_files << File.join(modified_directory, existing_file)
                end
              end
            end
          end

          existing_files
        end

        def get_post_existing_files(modified_files)
          modified_files.select{|f| File.exist? f}.to_a
        end

        def get_pre_file_sizes(snapshot_image, changed_files)
          return {} if changed_files.empty?

          #TODO split into multiple calls if there are too many files
          args = ['stat', '-c', '%s'] + changed_files
          result = Docker.run snapshot_image, args

          file_sizes = Hash.new
          result.output.each_line do |line|
            changed_file = changed_files[file_sizes.size]
            file_sizes[changed_file] = line.strip.to_i
          end

          file_sizes
        end

        def get_post_file_sizes(changed_files)
          file_sizes = Hash.new
          changed_files.each do |changed_file|
            file_sizes[changed_file] = File.size changed_file
          end
          file_sizes
        end

        def get_pre_hashes(snapshot_image, changed_files)
          return {} if changed_files.empty?

          #TODO split into multiple calls if there are too many files
          args = ['md5sum'] + changed_files
          result = Docker.run snapshot_image, args

          Citac::Utils::MD5.parse_md5sum_output result.output
        end

        def get_post_hashes(changed_files)
          Citac::Utils::MD5.hash_files changed_files
        end

        def create_snapshot_image
          hostname = Citac::Utils::System.hostname
          repository_name = "#{hostname}_snapshots"
          tag = SecureRandom.uuid

          Docker.commit hostname, repository_name, tag
        end

        def remove_snapshot_image(image)
          Docker.remove_image image if image
        rescue StandardError => e
          log_warn 'docker', "Failed to clean up snapshot image #{image}", e
        end
      end
    end
  end
end