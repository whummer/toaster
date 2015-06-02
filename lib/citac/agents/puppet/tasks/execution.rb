require_relative '../../../commons/integration/puppet'
require_relative '../../../commons/model'
require_relative '../../../commons/utils/serialization'

module Citac
  module Agents
    module Puppet
      class ExecutionTask
        def initialize(manifest_path, resources = nil)
          @manifest_path = manifest_path

          if resources
            resources = [resources] unless resources.respond_to?(:each)
            @resources = resources
          end
        end

        def execute(options = {})
          puppet_opts = options.dup
          puppet_opts[:raise_on_failure] = false

          if @resources && @resources.size > 0
            if @resources.size == 1
              puppet_opts[:resource] = @resources[0]
            else
              steps = []
              @resources.each do |resource|
                steps << Citac::Model::TestStep.new(:exec, resource)
              end
              Citac::Utils::Serialization.write_to_file steps, 'steps.yml'
              puppet_opts[:step_file] = 'steps.yml'
            end
          end

          Citac::Integration::Puppet.apply @manifest_path, puppet_opts
        end
      end
    end
  end
end