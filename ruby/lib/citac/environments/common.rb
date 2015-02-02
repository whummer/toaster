module Citac
  module Environments
    module EnvironmentManagerExtensions
      def find(options = {})
        os_name = options[:os_name]
        os_version = os_name ? options[:os_version] : nil
        spec_runner = options[:spec_runner]

        env = environments.find do |e|
          (os_name.nil? || e.os_name == os_name) &&
          (os_version.nil? || e.os_version == os_version) &&
          (spec_runner.nil? || e.spec_runners.include?(spec_runner))
        end

        raise "No suitable environment found for os '#{os_name}-#{os_version}' and '#{spec_runner}'" unless env

        env
      end
    end
  end
end