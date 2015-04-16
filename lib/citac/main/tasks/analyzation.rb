module Citac
  module Main
    module Tasks
      class AnalyzationTask
        attr_reader :spec

        def type
          :analyze
        end

        def initialize(repository, spec)
          @spec = spec
          @repository = repository
        end

        def after_execution(dir, operating_system, result, run)
          graphml = IO.read File.join(dir, 'dependencies.graphml'), :encoding => 'UTF-8'
          graph = Citac::Utils::Graphs::Graph.from_graphml graphml

          @repository.save_dependency_graph @spec, operating_system, graph
        end
      end
    end
  end
end