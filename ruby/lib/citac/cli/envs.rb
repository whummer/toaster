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

      desc 'update [<id>]', 'Updates package caches etc. on a specific or all environments.'
      def update(id = nil)
        env_mgr = ServiceLocator.environment_manager
        envs = id ? [env_mgr.get(id)] : env_mgr.environments.to_a

        envs.each do |env|
          puts "Updating #{env}..."
          env_mgr.update env, :output => :passthrough
        end
      end
    end
  end
end