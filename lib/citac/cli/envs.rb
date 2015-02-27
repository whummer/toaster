require 'thor'
require_relative 'ioc'

module Citac
  module CLI
    module EnvsSubcommands
      class Cache < Thor
        desc 'status', 'Gets the status of the caching proxy for network traffic.'
        def status
          env_mgr = ServiceLocator.environment_manager
          status = env_mgr.cache_enabled? ? 'enabled' : 'disabled'

          puts status
        end

        desc 'enable', 'Enables the caching proxy for network traffic. Requires root privileges.'
        def enable
          env_mgr = ServiceLocator.environment_manager
          if env_mgr.cache_enabled?
            puts 'Cache is already enabled.'
          else
            puts 'Starting caching proxy...'
            env_mgr.enable_caching
          end
        end

        desc 'disable', 'Disables the caching proxy for network traffic. Requires root privileges.'
        def disable
          env_mgr = ServiceLocator.environment_manager
          if env_mgr.cache_enabled?
            puts 'Stopping caching proxy...'
            env_mgr.disable_caching
          end
        end

        desc 'clear', 'Clears the cached files. Requires root privileges.'
        def clear
          env_mgr = ServiceLocator.environment_manager
          env_mgr.clear_cache
        end
      end
    end

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

      desc 'cache <command> <args...>', 'Interacts with the network traffic cache.'
      subcommand 'cache', EnvsSubcommands::Cache
    end
  end
end