require 'thor'
require_relative '../ioc'
require_relative '../evaluation/agent'
require_relative '../evaluation/repository'
require_relative '../evaluation/stg/test_suite_generator'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/colorize'

module Citac
  module Main
    module CLI
      class Eval < Thor
        desc 'once <connection>', 'Executes a single evaluation task'
        def once(connection)
          agent = create_agent connection
          agent.run_once
        end

        desc 'agent <connection>', 'Executes evaluation tasks continuously.'
        def agent(connection)
          agent = create_agent connection
          agent.run
        end

        desc 'stgparams', 'Creates various STG based test suites for further evaluation.'
        def stgparams
          repo = ServiceLocator.specification_repository
          env_mgr = ServiceLocator.environment_manager

          generator = Citac::Main::Evaluation::STG::TestSuiteGenerator.new repo, env_mgr
          generator.run
        end

        no_commands do
          def create_agent(connection)
            task_repository = create_repository connection
            spec_repository = ServiceLocator.specification_repository
            env_mgr = ServiceLocator.environment_manager

            ensure_cache_running

            Citac::Main::Evaluation::EvaluationAgent.new task_repository, spec_repository, env_mgr
          end

          def ensure_cache_running
            Citac::Utils::Exec.run 'citac', :args => %w(cache enable)
          rescue => e
            puts "Starting cache failed: #{e}".yellow
          end

          def create_repository(connection)
            case
              when connection.start_with?('local:')
                match = /^local:(?<path>.+)$/i.match connection
                raise "Wrong LOCAL connection identifier: #{connection}" unless match
                return Citac::Main::Evaluation::LocalTaskRepository.new match[:path]

              when connection.start_with?('ssh:')
                match = /^ssh:(?<user>[^@]+)@(?<host>[^:]+):(?<path>.+)$/i.match connection
                raise "Wrong SSH connection identifier: #{connection}" unless match
                return Citac::Main::Evaluation::SshTaskRepository.new match[:host], match[:user], match[:path]

              else
                raise "Unknown connection identifier: #{connection}"
            end
          end
        end
      end
    end
  end
end