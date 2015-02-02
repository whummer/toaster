module Citac
  module Environments
    class Environment
      attr_reader :id, :os_name, :os_version, :spec_runners

      def initialize(id, os_name, os_version, spec_runners)
        @id = id
        @os_name = os_name
        @os_version = os_version
        @spec_runners = spec_runners
      end

      def to_s
        "#{os_name}-#{os_version}/#{spec_runners.join(',')}/#{id}"
      end
    end
  end
end