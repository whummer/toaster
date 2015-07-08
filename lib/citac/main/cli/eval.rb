require 'thor'
require_relative '../ioc'
require_relative '../core/test_case_generators/simple'
require_relative '../core/test_case_generators/stg_based'
require_relative '../tasks/testing'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/utils/range'
require_relative '../evaluation/agent'
require_relative '../evaluation/task_repository'

module Citac
  module Main
    module CLI
      class Eval < Thor
        def initialize(*args)
          super

          @spec_repository = ServiceLocator.specification_repository
          @task_repository = Citac::Main::Evaluation::TaskRepository.new '/home/oliver/Temp/evaktasks'
          @env_mgr = ServiceLocator.environment_manager
          @agent = Citac::Main::Evaluation::EvaluationAgent.new @task_repository, @spec_repository, @env_mgr
          # @spec_service = ServiceLocator.specification_service
          # @exec_mgr = ServiceLocator.execution_manager
          # @env_mgr = ServiceLocator.environment_manager
        end

        desc 'once', 'Executes a single evaluation task'
        def once
          @agent.run_once
        end

        desc 'agent', 'Executes evaluation tasks continuously.'
        def agent
          @agent.run
        end
      end
    end
  end
end