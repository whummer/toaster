require_relative '../utils/graph'
require_relative '../model'

module Citac
  module Core
    class TestCaseGenerator
      def initialize(dependency_graph)
        @dependency_graph = dependency_graph
      end

      def generate_test_suite
        test_cases = []

        @dependency_graph.resources.each do |resource|
          test_cases << generate_idempotence_test_case(resource)

          @dependency_graph.ancestors(resource).each do |ancestor|
            test_cases << generate_preservation_test_case(resource, ancestor)
          end

          @dependency_graph.non_related_resources(resource).each do |non_related_resource|
            test_cases << generate_preservation_test_case(resource, non_related_resource)
          end
        end

        test_cases
      end

      def generate_idempotence_test_case(resource)
        test_case = Citac::Model::TestCase.new :idempotence, [resource]

        add_exec_step resource, test_case
        add_assert_step resource, test_case

        test_case
      end

      def generate_preservation_test_case(preserver, preserved)
        test_case = Citac::Model::TestCase.new :preservation, [preserver, preserved]

        add_exec_step preserved, test_case
        add_exec_step preserver, test_case
        add_assert_step preserved, test_case

        test_case
      end

      private

      def add_exec_step(resource, test_case)
        executed = test_case.executed_resources

        dependencies = @dependency_graph.ancestors resource
        dependencies.each do |dependency|
          test_case.add_exec_step dependency unless executed.include? dependency
        end

        test_case.add_exec_step resource
      end

      def add_assert_step(resource, test_case)
        test_case.add_assert_step resource
      end
    end
  end
end