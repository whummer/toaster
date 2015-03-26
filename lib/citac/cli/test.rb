require 'thor'
require_relative 'ioc'
require_relative '../core'
require_relative '../model'
require_relative '../agent/test_case_executor'

module Citac
  module CLI
    class Test < Thor
      def initialize(*args)
        super

        @repo = ServiceLocator.specification_repository
        @env_mgr = ServiceLocator.environment_manager
      end

      desc 'list <spec> <os>', 'Prints possible test cases for the given configuration specification.'
      def list(spec_id, os)
        os = Citac::Model::OperatingSystem.parse os
        _, test_suite = load_test_suite spec_id, os

        case_count = 0
        step_count = 0
        test_suite.each do |test_case|
          case_count += 1
          step_count += test_case.steps.size

          puts "#{case_count}\t#{test_case}"
        end

        puts
        puts "#{test_suite.size} test cases (#{step_count} steps)."
      end

      desc 'get <spec> <os> <case>', 'Gets the specified test case for the given configuration specification.'
      def get(spec_id, os, case_id)
        os = Citac::Model::OperatingSystem.parse os
        _, test_suite = load_test_suite spec_id, os
        case_id = Integer(case_id)

        test_case = test_suite[case_id - 1]
        puts test_case.to_yaml
      end

      option :print, :aliases => :p
      desc 'exec <spec> <os> <case>', 'Executes the specified test case for the given configuration specification.'
      def exec(spec_id, os, case_id)
        os = Citac::Model::OperatingSystem.parse os
        spec, test_suite = load_test_suite spec_id, os
        case_id = Integer(case_id)

        test_case = test_suite[case_id - 1]

        tce = Citac::Agent::TestCaseExecutor.new @repo, @env_mgr
        tce.run spec, os, test_case, options
      end

      no_commands do
        def load_test_suite(spec_id, os)
          spec_id = clean_spec_id spec_id

          spec = @repo.get spec_id

          dg = @repo.dependency_graph spec, os
          dg = Citac::Core::DependencyGraph.new dg

          tcg = Citac::Core::TestCaseGenerator.new dg
          test_suite = tcg.generate_test_suite

          return spec, test_suite
        end

        def clean_spec_id(spec_id)
          spec_id.gsub /\.spec\/?/i, ''
        end
      end
    end
  end
end