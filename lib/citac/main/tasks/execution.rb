module Citac
  module Main
    module Tasks
      class ExecutionTask
        attr_reader :spec
        attr_accessor :stepwise

        def type
          @stepwise ? :exec_stepwise : :exec
        end

        def command
          :exec
        end

        def initialize(spec)
          @spec = spec
          @stepwise = false
        end

        def additional_args
          result = []
          result << '-s' if @stepwise
          result
        end

        def after_execution(dir, operating_system, result, run)
          result
        end
      end
    end
  end
end