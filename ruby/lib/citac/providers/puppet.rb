require_relative 'registry'

module Citac
  module Providers
    class PuppetProvider
      class << self
        def script_extension; '.pp'; end

        def prepare_for_dependency_graph_generation(repository, spec, directory, run_script_io)
          copy_modules repository, spec, directory

          run_script_io.puts 'citac puppet graph --modulepath modules script.pp'# && mv script.expanded_relationships.graphml dependencies.graphml'
        end

        def prepare_for_run(repository, spec, directory, run_script_io)
          copy_modules repository, spec, directory

          run_script_io.puts 'citac-puppet apply --modulepath modules script.pp'
        end

        private

        def copy_modules(respository, spec, directory)
          respository.get_additional_files spec, directory
        end
      end
    end

    register 'puppet', PuppetProvider
  end
end