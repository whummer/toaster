module Citac
  module Main
    module Tasks
      module Puppet
        class ManifestSpecificationGenerator
          def initialize(environment_manager)
            @environment_manager = environment_manager
          end

          def generate(manifest_path)
            puts 'Setting up file structure...'

            manifest_name = File.basename manifest_path, '.pp'

            spec_dir = File.join File.dirname(manifest_path), "#{manifest_name}.spec"
            script_dir = File.join spec_dir, 'scripts'
            module_dir = File.join spec_dir, 'files', 'modules'

            FileUtils.mkdir_p script_dir

            puts 'Generating metadata...'

            oss = @environment_manager.operating_systems 'puppet'

            metadata = {
                'type' => 'puppet',
                'operating-systems' => oss.map { |os| os.to_s }
            }

            metadata_path = File.join spec_dir, 'metadata.json'
            IO.write metadata_path, JSON.pretty_generate(metadata), :encoding => 'UTF-8'

            script_path = File.join script_dir, 'default'
            FileUtils.copy manifest_path, script_path

            puts 'Done.'
            puts
            puts "IMPORTANT: Remember to copy every required module to '#{module_dir}'.".yellow
            puts "IMPORTANT: Remember to edit the supported operating systems in '#{metadata_path}'.".yellow
          rescue
            FileUtils.rm_rf spec_dir
            raise
          end
        end
      end
    end
  end
end
