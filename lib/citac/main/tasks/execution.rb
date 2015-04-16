module Citac
  module Main
    module Tasks
      class ExecutionTask
        attr_reader :spec

        def type
          :exec
        end

        def initialize(spec)
          @spec = spec
        end
      end
    end
  end
end