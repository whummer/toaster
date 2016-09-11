require 'thor'
require_relative '../ioc'

module Citac
  module Main
    module CLI
      class Cache < Thor
        def initialize(*args)
          super
          @env_mgr = ServiceLocator.environment_manager
        end

        desc 'status', 'Gets the status of the caching proxy for network traffic.'
        def status
          status = @env_mgr.cache_enabled? ? 'enabled' : 'disabled'
          puts status
        end

        desc 'enable', 'Enables the caching proxy for network traffic. Requires root privileges.'
        def enable
          if @env_mgr.cache_enabled?
            puts 'Cache is already enabled.'
          else
            puts 'Starting caching proxy...'
            @env_mgr.enable_caching
          end
        end

        desc 'disable', 'Disables the caching proxy for network traffic. Requires root privileges.'
        def disable
          if @env_mgr.cache_enabled?
            puts 'Stopping caching proxy...'
            @env_mgr.disable_caching
          end
        end

        desc 'clear', 'Clears the cached files. Requires root privileges.'
        def clear
          @env_mgr.clear_cache
        end

        option :count, :aliases => :n, :desc => 'The number of lines to print'
        option :follow, :aliases => :f, :type => :boolean, :desc => 'Enables continuous printing of accessed resources'
        desc 'logs [-n|--count <lines>] [-f|--follow]', 'Prints the last accessed resources.'
        def logs
          count = options[:count] ? options[:count].to_i : 20
          if options[:follow]
            @env_mgr.cache_stream_accessed_resources count
          else
            resources = @env_mgr.cache_last_accessed_resources count
            resources.each {|r| puts r}
          end
        end
      end
    end
  end
end