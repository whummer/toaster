require 'set'
require_relative '../model'

module Citac
  module Environments
    module EnvironmentManagerExtensions
      def get(env)
        return env if env.kind_of?(Citac::Model::Environment)
        environments.find {|e| e.id == env.to_s}
      end

      def find(options = {})
        operating_system = options[:operating_system]
        spec_runner = options[:spec_runner]

        env = environments.find do |e|
          (operating_system.nil? || e.operating_system.matches?(operating_system)) &&
          (spec_runner.nil? || e.spec_runners.include?(spec_runner))
        end

        raise "No suitable environment found for os '#{operating_system}' and '#{spec_runner}'" unless env

        env
      end

      def operating_systems(spec_runner = nil)
        oss = Set.new

        envs = environments
        envs = envs.select {|e| e.spec_runners.include? spec_runner} if spec_runner

        envs.each {|e| oss << e.operating_system}
        oss.to_a
      end

      def run_commands(env, commands, options = {})
        Dir.mktmpdir do |dir|
          script_path = File.join(dir, 'script.sh')
          File.open script_path, 'w', :encoding => 'UTF-8' do |f|
            f.puts '#!/bin/sh'
            f.puts 'cd /tmp/citac'

            cmdstr = commands.respond_to?(:join) ? commands.join($/) : commands.to_s
            f.puts cmdstr
          end

          run env, script_path, options
        end
      end

      def update(env, options = {})
        env = get env

        if env.operating_system.debian_based?
          cmds = 'apt-get update'
        end

        if defined? cmds
          options[:cleanup_instance] = false

          instance = run_commands env, 'apt-get update', options
          commit instance, env

          #TODO cleanup environment instance / docker container
        end
      end
    end
  end
end