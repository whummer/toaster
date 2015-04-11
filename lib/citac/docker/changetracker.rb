require 'securerandom'
require 'etc'
require_relative 'containers'
require_relative 'images'
require_relative '../utils/file_access_tracking'
require_relative '../utils/md5'
require_relative '../utils/system'
require_relative '../logging'

module Citac
  module Docker
    module ChangeTracker
      class FileStatus
        attr_reader :name, :size, :mode, :owner, :group

        def exists?
          @existing
        end

        def initialize(name, existing, size = nil, mode = nil, owner = nil, group = nil)
          @name = name
          @existing = existing
          @size = size
          @mode = mode
          @owner = owner
          @group = group
        end

        def eql?(other)
          #TODO add mode
          @name == other.name && @size == other.size && @owner == other.owner && @group == other.group
        end

        alias_method :==, :eql?

        def to_s
          "#{@name}, exists: #{@existing}, size: #{@size}, mode: #{@mode}, owner: #{@owner}, group: #{@group}"
        end
      end

      class << self
        def track_changes(command, options = {})
          snapshot_image = create_snapshot_image

          accessed_files, written_files = Citac::Utils::FileAccessTracking.track command, options

          #TODO generalize filter
          accessed_files.reject! {|f| f.start_with?('/opt/citac') || f.start_with?('/tmp/citac') || f.start_with?('/var/lib/puppet')}
          written_files.reject! {|f| f.start_with?('/opt/citac') || f.start_with?('/tmp/citac') || f.start_with?('/var/lib/puppet')}

          #puts 'WRITTEN FILES:' #TODO remove
          #written_files.each {|f| puts f} #TODO remove

          pre_states = get_pre_file_states snapshot_image, accessed_files
          post_states = get_post_file_states accessed_files

          #puts 'PRESTATES:' #TODO remove
          #pre_states.each {|fn, fs| puts "#{fn}: #{fs}"} #TODO remove
          #puts 'POSTSTATES:' #TODO remove
          #post_states.each {|fn, fs| puts "#{fn}: #{fs}"} #TODO remove

          new_files = []
          existing_files = []
          deleted_files = []
          temp_files = []
          changed_files = []
          touched_files = []
          read_files = []

          accessed_files.each do |accessed_file|
            pre = pre_states[accessed_file]
            post = post_states[accessed_file]

            if post.exists?
              if pre.exists?
                existing_files << accessed_file
              else
                new_files << accessed_file
              end
            else
              if pre.exists?
                deleted_files << accessed_file
              else
                temp_files << accessed_file
              end
            end
          end

          hash_compare_files = []
          existing_files.each do |existing_file|
            if written_files.include? existing_file
              if pre_states[existing_file] != post_states[existing_file]
                #puts "STATE MISMATCH '#{existing_file}': '#{pre_states[existing_file]}' vs. '#{post_states[existing_file]}'" #TODO remove
                changed_files << existing_file
              else
                hash_compare_files << existing_file
              end
            else
              read_files << existing_file
            end
          end

          pre_hashes = get_pre_hashes snapshot_image, hash_compare_files
          post_hashes = get_post_hashes hash_compare_files
          hash_compare_files.each do |hash_compare_file|
            if pre_hashes[hash_compare_file] == post_hashes[hash_compare_file]
              touched_files << hash_compare_file
            else
              #puts "HASH MISMATCH '#{hash_compare_file}': '#{pre_hashes[hash_compare_file]}' vs. '#{post_hashes[hash_compare_file]}'" #TODO remove
              changed_files << hash_compare_file
            end
          end

          unless new_files.empty?
            puts 'New files:'
            new_files.each do |new_file|
              puts " - #{new_file}"
            end
          end

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

          unless deleted_files.empty?
            puts 'Deleted files:'
            deleted_files.each do |deleted_file|
              puts " - #{deleted_file}"
            end
          end

          unless temp_files.empty?
            puts 'Temporary files (created and deleted):'
            temp_files.each do |temporary_file|
              puts " - #{temporary_file}"
            end
          end

          # unless read_files.empty?
          #   puts 'Read files (only read access):'
          #   read_files.each do |read_file|
          #     puts " - #{read_file}"
          #   end
          # end
        ensure
          remove_snapshot_image snapshot_image
        end

        private

        def get_pre_file_states(snapshot_image, accessed_files)
          escaped_file_names = accessed_files.map { |f| f.gsub ' ', '\ ' }.to_a
          cmd = ['xargs', '-n', '100', 'stat', '-c', '%n:%s:%A:%U:%G']
          result = Citac::Docker.run snapshot_image, cmd, :stdin => escaped_file_names, :raise_on_failure => false

          states = Hash.new
          result.stdout.each_line do |line|
            pieces = line.strip.split ':'
            filename = pieces[0]
            size = pieces[1].to_i
            mode = pieces[2] #TODO use numeric mode
            owner = pieces[3]
            group = pieces[4]

            states[filename] = FileStatus.new filename, true, size, mode, owner, group
          end

          accessed_files.each do |accessed_file|
            unless states.include? accessed_file
              #puts "Considering '#{accessed_file}' as not existing" #TODO remove
              states[accessed_file] = FileStatus.new accessed_file, false
            end
          end

          states
        end

        def get_post_file_states(accessed_files)
          users = Hash.new
          groups = Hash.new

          Etc.passwd {|u| users[u.uid] = u.name}
          Etc.group {|g| groups[g.gid] = g.name}

          states = Hash.new
          accessed_files.each do |accessed_file|
            if File.exists? accessed_file
              stat = File.stat accessed_file
              states[accessed_file] = FileStatus.new accessed_file, true, stat.size, stat.mode, users[stat.uid], groups[stat.gid]
            else
              states[accessed_file] = FileStatus.new accessed_file, false
            end
          end

          states
        end

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