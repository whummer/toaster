require 'set'
require 'thor'
require_relative '../../commons/model'
require_relative '../../commons/utils/mathex'
require_relative '../ioc'
require_relative '../core/stg'
require_relative '../core/stg_builder'

module Citac
  module Main
    module CLI
      class Graphs < Thor
        def initialize(*args)
          super

          @repo = ServiceLocator.specification_repository
          @spec_service = ServiceLocator.specification_service
        end

        option :namesonly, :aliases => :n, :type => :boolean, :desc => 'Enables outputting resource names only.'
        option :expanded, :aliases => :e, :type => :boolean, :desc => 'Print the expanded dependecy graph.'
        option :format, :aliases => :f, :default => :dot, :desc => 'The output graph format.'
        option :structureonly, :aliases => :s, :type => :boolean, :desc => 'Discards all labels.'
        desc 'dg <spec> <os>', 'Prints the dependency graph of the configuration specification.'
        def dg(spec_id, os)
          dg = load_dg spec_id, os
          dg.reduce unless options[:expand]

          print_graph dg.graph, options
        end

        desc 'of <spec> <os>', 'Prints the ordering factor of the partial order of the configuration specification.'
        def of(spec_id, os)
          dg = load_dg spec_id, os
          puts dg.ordering_factor
        end

        option :namesonly, :aliases => :n, :type => :boolean, :desc => 'Enables outputting resource names only.'
        option :format, :aliases => :f, :default => :dot, :desc => 'The output graph format.'
        option :paths, :aliases => :p, :type => :boolean, :desc => 'Print the paths to stderr.'
        option :pathcount, :aliases => :c, :type => :boolean, :desc => 'Print the path count to stderr.'
        option :structureonly, :aliases => :s, :type => :boolean, :desc => 'Discards all labels.'
        option :printvisits, :aliases => :z, :type => :boolean, :desc => 'Prints edge thickness according to number of edge visits.'
        desc 'stg <spec> <os>', 'Generates the STG of the configuration specification.'
        def stg(spec_id, os)
          dg = load_dg spec_id, os
          stg = dg.to_stg

          print_graph stg, options
        end

        option :namesonly, :aliases => :n, :type => :boolean, :desc => 'Enables outputting resource names only.'
        option :format, :aliases => :f, :default => :dot, :desc => 'The output graph format.'
        option :paths, :aliases => :p, :type => :boolean, :desc => 'Print the paths to stderr.'
        option :pathcount, :aliases => :c, :type => :boolean, :desc => 'Print the path count to stderr.'
        option :structureonly, :aliases => :s, :type => :boolean, :desc => 'Discards all labels.'
        option :addedges, :aliases => :e, :type => :boolean, :desc => 'Adds missing edges between existing nodes.'
        option :expand, :aliases => :x, :default => '0', :desc => 'Expands the minimal STG by the given number of steps.'
        option :printvisits, :aliases => :z, :type => :boolean, :desc => 'Prints edge thickness according to number of edge visits.'
        desc 'minstg <spec> <os>', 'Generates the minimal STG of the configuration specification.'
        def minstg(spec_id, os)
          dg = load_dg spec_id, os

          stg_builder = Citac::Core::StgBuilder.new dg
          dg.resources.each do |resource|
            stg_builder.add_state [resource]

            # ancestors are handled by state reaching resource

            dg.non_related_resources(resource).each do |non_related_resource|
              all = dg.ancestors(resource) + dg.ancestors(non_related_resource) + [resource, non_related_resource]
              stg_builder.add_transition (all - [resource]), all
              stg_builder.add_transition (all - [non_related_resource]), all
            end
          end

          stg_builder.expand options[:expand].to_i
          stg_builder.add_missing_edges if options[:addedges]

          stg = stg_builder.stg

          print_graph stg, options
        end

        no_commands do
          def load_dg(spec_id, os)
            spec = @repo.get spec_id
            os = Citac::Model::OperatingSystem.parse os
            os = @spec_service.get_specific_operating_system spec, os
            dg = @spec_service.dependency_graph spec, os

            return dg
          end

          def print_graph(stg, options)
            edge_cover_paths = Citac::Utils::Graphs::DAG.edge_cover_paths(stg) if options[:paths] || options[:pathcount]

            opts = {
                :node_label_getter => lambda{|n| node_label n, options},
                :edge_label_getter => lambda{|e| edge_label e, options}
            }

            if edge_cover_paths && options[:printvisits]
              edge_visits = Hash.new 0
              edge_cover_paths.each do |path|
                path.each_with_index do |target, index|
                  next if index == 0

                  source = path[index - 1]
                  edge = stg.edge source, target
                  edge_visits[edge] += 1
                end
              end

              opts[:edge_attribute_getter] = lambda{|e|
                (edge_visits[e] >= 25) ? {:penwidth => 25, :color => 'red'} : {:penwidth => edge_visits[e]}
              }
            end

            formatted_stg = stg.send "to_#{options[:format]}", opts
            puts formatted_stg

            if options[:paths]
              $stderr.puts 'Edge Cover:' if options[:paths]
              edge_cover_paths.each do |path|
                $stderr.puts path.collect{|n| node_label n, options}.join(' -> ') if options[:paths]
              end

              $stderr.puts '-----'

              $stderr.puts 'Path Cover:'
              stg.each_path [], nil do |path|
                $stderr.puts path.collect{|n| node_label n, options}.join(' -> ')
              end
            end

            if options[:pathcount]
              $stderr.puts "Edge Cover Path Count: #{edge_cover_paths.size}"
              $stderr.puts "Path Cover Path Count: #{stg.dag_path_count}"
            end
          end

          NAME_EXP = /\[(?<name>[^\]]+)\]/

          def node_label(node, options)
            return '' if options[:structureonly]
            return resource_name node.label, options unless node.label.kind_of? Array
            return '[]' if node.label.empty?
            node.label.map{|r| resource_name r, options}.join ', '
          end

          def edge_label(edge, options)
            return '' if options[:structureonly]
            resource_name edge.label, options
          end

          def resource_name(name, options)
            if options[:namesonly]
              match = NAME_EXP.match name
              return match[:name] if match
            end

            name
          end
        end
      end
    end
  end
end