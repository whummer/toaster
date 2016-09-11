require_relative '../../../commons/utils/exec'
require_relative 'base'

module Citac
  module Main
    module Evaluation
      class AnalyzationTask < EvaluationTask
        def fulfilled?(spec, operating_system)
          spec_repository.has_dependency_graph? spec, operating_system
        rescue
          return false
        end

        def execute_os(spec, operating_system)
          args = ['spec', 'analyze', spec.id, operating_system]

          result = Citac::Utils::Exec.run 'citac', :args => args, :output => :passthrough, :raise_on_failure => false
          result.success? ? :success_completed : :failure
        end
      end
    end
  end
end