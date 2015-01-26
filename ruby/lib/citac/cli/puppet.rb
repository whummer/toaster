require 'thor'
require_relative '../puppet/utils/graph_generation'

module Citac
  module CLI
    class Puppet < Thor
      desc 'graph <file1> <file2> <file...>', 'Generations dependency graphs for the given Puppet manifests.'
      def graph(*files)
        files.each do |file|
          begin
            puts "Generating graphs for '#{file}' ..."
            Citac::Puppet::Utils::GraphGeneration.generate_graphs file
          rescue StandardError => e
            STDERR.puts "Failed to generate graphs for '#{file}': #{e}"
          end
        end
      end
    end
  end
end