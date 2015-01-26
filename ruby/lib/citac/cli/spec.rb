require 'thor'
require_relative '../specification/core'

module Citac
  module CLI
    class Spec < Thor
      desc 'traces <file>', 'Prints all possible execution traces for the given configuration specification.'
      def traces(file)
        spec = parse_spec file
        stg = spec.to_stg

        stg.each_path [], spec.resources do |path|
          puts path.join ' -> '
        end
      end

      desc 'tc <file>', 'Calculates the number of possible execution traces for the given configuration specification.'
      def tc(file)
        spec = parse_spec file
        stg = spec.to_stg

        trace_count = stg.path_count [], spec.resources
        puts trace_count
      end

      desc 'stg <file>', 'Generated the STG for the given configuration specification.'
      def stg(file)
        spec = parse_spec file
        stg = spec.to_stg
        puts stg.to_dot(:node_label_getter => lambda{|n| n.label.join(', ')})
      end

      no_commands do
        def parse_spec(file_path)
          ext = File.extname file_path

          case ext
            when '.graphml'
              File.open file_path, 'r' do |f|
                return Citac::ConfigurationSpecification.from_graphml f
              end

            when '.confspec'
              File.open file_path, 'r' do |f|
                return Citac::ConfigurationSpecification.from_confspec f
              end

            else
              raise "Unknown file format: #{ext}"
          end
        end
      end
    end
  end
end