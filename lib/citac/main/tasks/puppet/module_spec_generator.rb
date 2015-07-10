require_relative '../../../../../lib/citac/commons/integration/puppet/forge'

module Citac
  module Main
    module Tasks
      module Puppet
        class ModuleSpecificationGenerator
          def generate(module_name, version = nil)
            puts 'Setting up file structure...'

            mod = Citac::Puppet::Forge::PuppetForgeClient.get_module module_name
            version ||= mod.current_version

            spec_dir = "#{module_name}-#{version}.spec"
            module_dir = File.join spec_dir, 'files', 'modules'

            FileUtils.mkdir_p spec_dir
            FileUtils.mkdir_p File.join spec_dir, 'scripts'
            FileUtils.mkdir_p module_dir

            puts 'Generating metadata...'

            metadata = {
                'type' => 'puppet',
                'operating-systems' => mod.operating_systems.map { |os| os.to_s }
            }

            metadata_path = File.join spec_dir, 'metadata.json'
            IO.write metadata_path, JSON.pretty_generate(metadata), :encoding => 'UTF-8'

            script_path = File.join spec_dir, 'scripts', 'default'
            IO.write script_path, "# #{mod.forge_url}\nTODO", :encoding => 'UTF-8'

            puts 'Fetching puppet modules...'

            arguments = ['--modulepath', module_dir]
            arguments += ['--version', version] if version
            arguments << module_name

            Citac::Utils::Exec.run 'puppet module install', :args => arguments, :stdout => :passthrough

            puts 'Done.'
            puts
            puts "IMPORTANT: Remember to edit '#{script_path}' to include the module properly.".yellow
            puts "WARN: No supported operating system has been detected. Edit '#{metadata_path}' manually".yellow if mod.operating_systems.empty?
          rescue
            FileUtils.rm_rf spec_dir
            raise
          end
        end
      end
    end
  end
end