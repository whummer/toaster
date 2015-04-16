require_relative '../../../commons/integration/puppet'

module Citac
  module Agents
    module Puppet
      class ExecutionTask
        def initialize(manifest_path, resource_name = nil)
          @manifest_path = manifest_path
          @resource_name = resource_name
        end

        def execute(options = {})
          puppet_opts = options.dup
          puppet_opts[:resource] = @resource_name
          puppet_opts[:raise_on_failure] = false

          Citac::Integration::Puppet.apply @manifest_path, puppet_opts
        end
      end
    end
  end
end