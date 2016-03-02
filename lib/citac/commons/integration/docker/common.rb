require_relative '../../utils/exec'

module Citac
  module Integration
    module Docker
      def self.uses_sha256prefix?
        unless defined? @uses_sha256prefix
          result = Citac::Utils::Exec.run 'docker images --no-trunc'
          @uses_sha256prefix = result.output.include? 'sha256:'
        end

        @uses_sha256prefix
      end
    end
  end
end