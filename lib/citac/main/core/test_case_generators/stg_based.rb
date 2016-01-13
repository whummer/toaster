require 'set'
require_relative '../../../commons/model/test'
require_relative '../../../commons/utils/graph'
require_relative '../stg_builder'

module Citac
  module Main
    module Core
      module TestCaseGenerators
        class StgBasedTestCaseGenerator
          attr_reader :dependency_graph
          attr_accessor :expansion, :all_edges, :coverage, :edge_limit

          def initialize(dependency_graph)
            @dependency_graph = dependency_graph

            @expansion = 0
            @all_edges = true
            @coverage = :edge
            @edge_limit = 3
          end

          def generate_test_suite
            test_suite = Citac::Model::TestSuite.new get_name

            stg = build_stg

            edge_visits = Hash.new 0
            each_path stg do |path|
              test_case = build_test_case stg, path, edge_visits
              test_suite.add_test_case test_case unless test_case.steps.empty?
            end

            test_suite.finish
            test_suite
          end

          private

          def get_name
            "stg (expansion = #{@expansion}, all edges = #{@all_edges || false}, coverage = #{@coverage}, edge limit = #{@edge_limit})"
          end

          def build_stg
            stg_builder = StgBuilder.new @dependency_graph
            stg_builder.add_minimal_states
            stg_builder.expand @expansion if @expansion > 0
            stg_builder.add_missing_edges if @all_edges

            stg_builder.stg
          end

          def each_path(stg)
            case @coverage
              when :edge
                Citac::Utils::Graphs::DAG.edge_cover_paths(stg).each do |path|
                  yield path
                end
              when :path
                stg.each_path [] do |path|
                  yield path
                end
              else
                raise "Unknown coverage type: #{@coverage}"
            end
          end

          def build_test_case(stg, path, edge_visits)
            test_case = Citac::Model::TestCase.new

            path.each_with_index do |current_node, index|
              next if index == 0

              last_node = path[index - 1]
              edge = stg.edge last_node, current_node

              executed_resource = edge.label
              test_case.add_exec_step executed_resource

              if edge_visits[edge] < @edge_limit
                property = Citac::Model::Property.new :idempotence, [executed_resource]
                test_case.add_assert_step executed_resource, property

                current_node.label.each do |assertion_resource|
                  next if assertion_resource == executed_resource

                  property = Citac::Model::Property.new :preservation, [executed_resource, assertion_resource]
                  test_case.add_assert_step assertion_resource, property
                end
              end

              edge_visits[edge] += 1
            end

            test_case.reduce
            test_case
          end
        end
      end
    end
  end
end