require 'thor'

require_relative 'cli/spec'
require_relative 'cli/runs'
require_relative 'cli/test'
require_relative 'cli/puppet'
require_relative 'cli/envs'
require_relative 'cli/cache'
require_relative '../version'
require_relative 'ioc'

module Citac
  module Main
    module CLI
      class Main < Thor
        desc 'spec <command> <args...>', 'Configuration specification related commands.'
        subcommand 'spec', Spec

        desc 'runs <command> <args...>', 'Commands related to saved runs.'
        subcommand 'runs', Runs

        desc 'test <command> <args...>', 'Test execution related commands.'
        subcommand 'test', Test

        desc 'puppet <command> <args...>', 'Puppet related commands.'
        subcommand 'puppet', Puppet

        desc 'envs <command> <args...>', 'Test environments related commands.'
        subcommand 'envs', Envs

        desc 'cache <command> <args...>', 'Commands for controlling the network traffic cache.'
        subcommand 'cache', Cache

        desc 'clear [<spec1> <spec2> ...]', 'Clears all saved data for the given configuration specifications.'
        def clear(*specs)
          repo = ServiceLocator.specification_repository
          specs = repo.specs if specs.empty?

          specs.each do |spec|
            spec = repo.get spec

            puts "Clearing data for #{spec}..."
            repo.clear spec
          end
        end

        desc 'version', 'Prints the application version.'
        def version
          puts Citac::VERSION
        end
      end
    end
  end
end