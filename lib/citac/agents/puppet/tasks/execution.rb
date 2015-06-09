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
              test_case = Citac::Model::TestCase.new
              @resources.each do |resource|
                test_case.add_exec_step resource
              end
              Citac::Utils::Serialization.write_to_file test_case, 'test_case.yml'
              puppet_opts[:test_case_file] = 'test_case.yml'
              puppet_opts[:test_case_result_file] = '/dev/null'
              puppet_opts[:settings_file] = '/dev/null'
            end
          end

          Citac::Integration::Puppet.apply @manifest_path, puppet_opts
        ensure
          File.delete 'test_case.yml' if @resources && @resources.size > 1
        end
      end
    end
  end
end