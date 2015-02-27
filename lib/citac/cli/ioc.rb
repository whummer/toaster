require_relative '../config'
require_relative '../data/filesystem'
require_relative '../environments/docker'

module Citac
  module CLI
    class ServiceLocator
      def self.environment_manager
        unless @environment_manager
          @environment_manager = Citac::Environments::DockerEnvironmentManager.new
        end

        @environment_manager
      end

      def self.specification_repository
        unless @specification_repository
          path = Citac::Config.spec_dir
          @specification_repository = Citac::Data::FileSystemSpecificationRepository.new path
        end

        @specification_repository
      end
    end
  end
end