require_relative '../core/dependency_graph'
require_relative '../tasks/analyzation'

module Citac
  module Main
    module Services
      class SpecificationService
        def initialize(repository, environment_manager, execution_manager)
          @repository = repository
          @environment_manager = environment_manager
          @execution_manager = execution_manager
        end

        def get_specific_operating_system(spec, operating_system)
          env = @environment_manager.find :operating_system => operating_system, :spec_runner => spec.type
          env.operating_system
        end

        def dependency_graph(spec, operating_system, options = {})
          unless operating_system && operating_system.specific?
            operating_system = get_specific_operating_system spec, operating_system
          end

          if (!@repository.has_dependency_graph?(spec, operating_system)) || options[:force_regeneration]
            task = Citac::Main::Tasks::AnalyzationTask.new @repository, spec
            @execution_manager.execute task, operating_system, options
          end

          graph = @repository.dependency_graph spec, operating_system
          Citac::Core::DependencyGraph.new graph
        end
      end
    end
  end
end