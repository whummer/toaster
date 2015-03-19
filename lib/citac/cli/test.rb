require 'thor'
require_relative 'ioc'
require_relative '../core'
require_relative '../model'

module Citac
  module CLI
    class Test < Thor
      desc 'tc <spec> <os>', 'Prints possible test cases for the given configuration specification.'
      def tc(spec_id, os)
        spec_id = clean_spec_id spec_id
        os = Citac::Model::OperatingSystem.parse os

        repo = ServiceLocator.specification_repository
        spec = repo.get spec_id

        dg = repo.dependency_graph spec, os
        dg = Citac::Core::DependencyGraph.new dg

        tcg = Citac::Core::TestCaseGenerator.new dg
        test_suite = tcg.generate_test_suite

        step_count = 0
        test_suite.each do |test_case|
          puts test_case
          step_count += test_case.steps.size
        end

        puts
        puts "#{test_suite.size} test cases (#{step_count} steps)."
      end

      no_commands do
        def clean_spec_id(spec_id)
          spec_id.gsub /\.spec\/?/i, ''
        end
      end
    end
  end
end