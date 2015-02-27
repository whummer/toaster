require 'thor'
require_relative '../core'

module Citac
  module CLI
    class Dg < Thor
      desc 'traces <file>', 'Prints all possible execution traces for the given dependency graph.'
      def traces(file)
        spec = parse_spec file
        stg = spec.to_stg

        stg.each_path [], spec.resources do |path|
          puts path.join ' -> '
        end
      end

      desc 'tc <file>', 'Calculates the number of possible execution traces for the given dependency graph.'
      def tc(file)
        spec = parse_spec file
        stg = spec.to_stg

        trace_count = stg.path_count [], spec.resources
        puts trace_count
      end

      desc 'stg <file>', 'Generated the STG for the given dependency graph.'
      def stg(file)
        spec = parse_spec file
        stg = spec.to_stg
        puts stg.to_dot(:node_label_getter => lambda{|n| n.label.join(', ')})
      end

      no_commands do
        def specdir
          '.'
        end

        def parse_spec(file_path)
          ext = File.extname file_path

          case ext
            when '.graphml'
              File.open file_path, 'r' do |f|
                return Citac::Core::DependencyGraph.from_graphml f
              end

            when '.confspec'
              File.open file_path, 'r' do |f|
                return Citac::Core::DependencyGraph.from_confspec f
              end

            else
              raise "Unknown file format: #{ext}"
          end
        end
      end
    end
  end
end