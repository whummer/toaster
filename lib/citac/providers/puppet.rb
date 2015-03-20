require_relative 'registry'

module Citac
  module Providers
    class PuppetProvider
      class << self
        def script_extension; '.pp'; end

        def prepare_for_dependency_graph_generation(repository, spec, directory, run_script_io)
          copy_modules repository, spec, directory

          run_script_io.puts 'citac puppet graph --modulepath modules script.pp && mv script.expanded_relationships.graphml dependencies.graphml'
        end

        def prepare_for_run(repository, spec, directory, run_script_io, options = {})
          copy_modules repository, spec, directory

          cmd = 'citac puppet exec --modulepath modules script.pp'
          cmd += ' -t -o trace.json' if options[:trace]

          run_script_io.puts cmd
        end

        def prepare_for_test_case_execution(repository, spec, directory, run_script_io)
          copy_modules repository, spec, directory

          cmd = 'citac puppet testexec --modulepath modules script.pp test_case.yml'

          run_script_io.puts cmd
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