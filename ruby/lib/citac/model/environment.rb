module Citac
  module Model
    class Environment
      attr_reader :id, :operating_system, :spec_runners

      def initialize(id, operating_system, spec_runners)
        @id = id
        @operating_system = operating_system
        @spec_runners = spec_runners
      end

      def to_s
        "#{@operating_system}/#{spec_runners.join(',')}/#{id}"
      end
    end

    class EnvironmentInstance
      attr_reader :id, :environment, :run_result

      def initialize(id, environment, run_result)
        @id = id
        @environment = environment
        @run_result = run_result
      end
    end
  end
end