require 'securerandom'
require 'etc'

require_relative '../../commons/integration/docker'
require_relative '../../commons/integration/strace'
require_relative '../../commons/integration/md5sum'
require_relative '../../commons/logging'
require_relative '../../commons/model/change_tracking'
require_relative '../../commons/utils/md5'
require_relative '../../commons/utils/system'
require_relative 'file_status'

module Citac
  module ChangeTrackers
    module Docker
      module ChangeTracker
        class << self
          def track_changes(command, settings, options = {})
            exclusion_patterns = settings.exclusion_patterns.dup
            add_default_exclusion_patterns exclusion_patterns

            snapshot_image = create_snapshot_image

            strace_opts = options.dup
            strace_opts[:start_markers] = settings.start_markers
            strace_opts[:end_markers] = settings.end_markers

            accessed_files, result, syscalls = Citac::Integration::Strace.track_file_access command, strace_opts
            accessed_files.each {|f| log_debug $prog_name, "Accessed file: #{f}"}

            accessed_files.reject! { |f| exclusion_patterns.any? { |p| f =~ p } }

            change_summary = compare_files snapshot_image, accessed_files
            change_summary.additional_data[:syscalls] = syscalls.join $/
            return change_summary, result
          ensure
            remove_snapshot_image snapshot_image
          end

          private

          def add_default_exclusion_patterns(patterns)
            patterns << /^\/dev\//
            patterns << /^\/proc\//
            patterns << /^\/sys\//
            patterns << /^\/opt\/citac\//
            patterns << /^\/tmp\/citac\//
            patterns << /^\/var\/lib\/puppet\//
          end

          def create_snapshot_image
            hostname = Citac::Utils::System.hostname
            repository_name = "#{hostname}_snapshots"
            tag = SecureRandom.uuid

            Citac::Integration::Docker.commit hostname, repository_name, tag
          end

          def remove_snapshot_image(image)
            Citac::Integration::Docker.remove_image image if image
          rescue StandardError => e
            log_warn 'citac-changetracker-docker', "Failed to clean up snapshot image #{image}", e
          end

          def compare_files(snapshot_image, accessed_files)
            pre_states = get_pre_file_states snapshot_image, accessed_files
            post_states = get_post_file_states accessed_files

            pre_states.each_value { |fs| log_debug 'citac-changetracker-docker', "PRE_STATE:  #{fs}" }
            post_states.each_value { |fs| log_debug 'citac-changetracker-docker', "POST_STATE: #{fs}" }

            change_summary = Citac::Model::ChangeSummary.new

            hash_compare_files = []
            accessed_files.each do |accessed_file|
              pre = pre_states[accessed_file]
              post = post_states[accessed_file]

              if post.exists?
                if pre.exists?
                  if pre != post
                    log_info $prog_name, "STATE MISMATCH '#{accessed_file}': '#{pre}' vs. '#{post}'"
                    change_summary.changes << Citac::Model::Change.new(:file, :changed, accessed_file)
                  else
                    hash_compare_files << accessed_file unless pre.directory? || post.directory?
                  end
                else
                  change_summary.changes << Citac::Model::Change.new(:file, :new, accessed_file)
                end
              else
                if pre.exists?
                  change_summary.changes << Citac::Model::Change.new(:file, :deleted, accessed_file)
                else
                  change_summary.touches << Citac::Model::Change.new(:file, :temp, accessed_file)
                end
              end
            end

            pre_hashes = get_pre_hashes snapshot_image, hash_compare_files
            post_hashes = get_post_hashes hash_compare_files
            hash_compare_files.each do |hash_compare_file|
              pre = pre_hashes[hash_compare_file]
              post = post_hashes[hash_compare_file]
              if pre == post
                change_summary.touches << Citac::Model::Change.new(:file, :touched, hash_compare_file)
              else
                log_info $prog_name, "HASH MISMATCH '#{hash_compare_file}': '#{pre}' vs. '#{post}'"
                change_summary.changes << Citac::Model::Change.new(:file, :changed, hash_compare_file)
              end
            end

            change_summary
          end

          def get_pre_file_states(snapshot_image, accessed_files)
            return Hash.new if accessed_files.empty?

            escaped_file_names = accessed_files.map { |f| f.gsub ' ', '\ ' }.to_a
            cmd = %w(xargs -n 100 stat -L -c %n:%s:%a:%U:%G:%F)
            result = Citac::Integration::Docker.run snapshot_image, cmd, :stdin => escaped_file_names, :raise_on_failure => false

            states = Hash.new
            result.stdout.each_line do |line|
              pieces = line.strip.split ':'
              filename = pieces[0]
              size = pieces[1].to_i
              mode = pieces[2].to_i(8) % 512
              owner = pieces[3]
              group = pieces[4]
              directory = pieces[5].downcase.include? 'directory'

              states[filename] = FileStatus.new filename, true, size, mode, owner, group, directory
            end

            accessed_files.each do |accessed_file|
              unless states.include? accessed_file
                log_debug 'citac-changetracker-docker', "Considering '#{accessed_file}' as not existing"
                states[accessed_file] = FileStatus.new accessed_file, false
              end
            end

            states
          end

          def get_post_file_states(accessed_files)
            return Hash.new if accessed_files.empty?

            users = Hash.new
            groups = Hash.new

            Etc.passwd { |u| users[u.uid] = u.name }
            Etc.group { |g| groups[g.gid] = g.name }

            states = Hash.new
            accessed_files.each do |accessed_file|
              if File.exists? accessed_file
                stat = File.stat accessed_file
                mode = stat.mode % 512
                states[accessed_file] = FileStatus.new accessed_file, true, stat.size, mode, users[stat.uid], groups[stat.gid], stat.directory?
              else
                states[accessed_file] = FileStatus.new accessed_file, false
              end
            end

            states
          end

          def get_pre_hashes(snapshot_image, changed_files)
            return Hash.new if changed_files.empty?

            escaped_file_names = changed_files.map { |f| f.gsub ' ', '\ ' }.to_a

            cmd = %w(xargs -n 100 md5sum)
            result = Citac::Integration::Docker.run snapshot_image, cmd, :stdin => escaped_file_names

            Citac::Integration::Md5sum.parse_output result.output
          end

          def get_post_hashes(changed_files)
            return Hash.new if changed_files.empty?

            Citac::Utils::MD5.hash_files changed_files
          end
        end
      end
    end
  end
end
