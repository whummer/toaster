require_relative 'config'
require_relative 'data/filesystem'
require_relative 'data/database'
require_relative 'environments/docker'
require_relative 'tasks/execution_manager'
require_relative 'services/spec_service'

module Citac
  module Main
    class ServiceLocator
      def self.environment_manager
        @environment_manager ||= Citac::Environments::DockerEnvironmentManager.new
      end

      def self.specification_repository
        # @specification_repository ||= Citac::Data::FileSystemSpecificationRepository.new Citac::Config.spec_dir
        @specification_repository ||= Citac::Data::DatabaseSpecificationRepository.new Citac::Config.spec_dir
      end

      def self.execution_manager
        @execution_manager ||= Citac::Main::Tasks::ExecutionManager.new specification_repository, environment_manager
      end

      def self.specification_service
        @specification_service ||= Citac::Main::Services::SpecificationService.new specification_repository, environment_manager, execution_manager
      end
    end
  end
end