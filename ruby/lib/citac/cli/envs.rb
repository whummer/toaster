require 'thor'
require_relative 'ioc'

module Citac
  module CLI
    class Envs < Thor
      desc 'list', 'Lists all available environments.'
      def list
        ServiceLocator.environment_manager.environments.each do |env|
          puts env
        end
      end
    end
  end
end