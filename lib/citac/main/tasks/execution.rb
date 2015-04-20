module Citac
  module Main
    module Tasks
      class ExecutionTask
        attr_reader :spec
        attr_accessor :stepwise

        def type
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
      end
    end
  end
end