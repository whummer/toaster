require 'thor'

require_relative 'dg'
require_relative 'envs'
require_relative 'puppet'
require_relative 'spec'
require_relative '../version'

module Citac
  module CLI
    class CitacCLI < Thor
      desc 'dg <command> <args...>', 'Dependency graph related commands'
      subcommand 'dg', Dg

      desc 'envs <command> <args...>', 'Test environments related commands'
      subcommand 'envs', Envs

      desc 'puppet <command> <args...>', 'Puppet specific commands'
      subcommand 'puppet', Puppet

      desc 'spec <command> <args...>', 'Configuration specification related commands'
      subcommand 'spec', Spec

      desc 'version', 'Prints the version number.'
      def version
        puts Citac::VERSION
      end
    end
  end
end