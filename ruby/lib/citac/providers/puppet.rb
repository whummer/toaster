require_relative 'registry'

module Citac
  module Providers
    class PuppetProvider
      def self.script_extension
        '.pp'
      end

      def self.write_preparation_code(io, spec)
        required_modules = spec.type_metadata['required-modules'] || []
        required_modules.each do |mod|
          name = mod['name']
          version = mod['version']

          options = ''
          options << " --version #{version}" if version

          io.puts "puppet module install #{options} #{name}"
        end
      end

      def self.write_dependency_graph_code(io, script_name, graph_name)
        generated_graph_name = "#{File.basename script_name, '.*'}.expanded_relationships.graphml"

        io.puts "citac puppet graph \"#{script_name}\" && mv \"#{generated_graph_name}\" \"#{graph_name}\""
        #io.puts ""
      end
    end

    register 'puppet', PuppetProvider
  end
end