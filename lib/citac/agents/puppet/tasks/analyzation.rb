require_relative '../../../commons/integration/puppet'

module Citac
  module Agents
    module Puppet
      class AnalyzationTask
        def initialize(manifest_path)
          @manifest_path = manifest_path
        end

        def execute(options = {})
          puppet_opts = options.dup
          puppet_opts[:graph_types] = [:expanded_relationships]

          graphs, _ = Citac::Integration::Puppet.generate_graphs @manifest_path, puppet_opts
          graphs[:expanded_relationships]
        end
      end
    end
  end
end