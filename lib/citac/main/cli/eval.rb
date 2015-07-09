require 'thor'
require_relative '../ioc'
require_relative '../evaluation/agent'
require_relative '../evaluation/repository'

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

        no_commands do
          def create_agent(connection)
            task_repository = create_repository connection
            spec_repository = ServiceLocator.specification_repository
            env_mgr = ServiceLocator.environment_manager

            Citac::Main::Evaluation::EvaluationAgent.new task_repository, spec_repository, env_mgr
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