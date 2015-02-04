require 'set'

module Citac
  module Environments
    module EnvironmentManagerExtensions
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
    end
  end
end