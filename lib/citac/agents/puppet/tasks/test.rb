require 'tmpdir'
require_relative '../../../commons/utils/serialization'
require_relative '../../../commons/integration/puppet'
require_relative '../../../commons/model'

module Citac
  module Agents
    module Puppet
      class TestTask
        attr_accessor :file_exclusion_patterns, :state_exclusion_patterns

        def initialize(manifest_path, test_case)
          @manifest_path = manifest_path
          @test_case = test_case
          @file_exclusion_patterns = []
          @state_exclusion_patterns = []
        end

        def execute(options = {})
          Dir.mktmpdir do |dir|
            test_case_file = File.join dir, 'test_case.yml'
            test_case_result_file = File.join dir, 'test_case_result.yml'
            settings_file = File.join dir, 'settings.yml'

            Citac::Utils::Serialization.write_to_file @test_case, test_case_file

            change_tracking_settings = Citac::Model::ChangeTrackingSettings.new
            change_tracking_settings.file_exclusion_patterns = @file_exclusion_patterns
            change_tracking_settings.state_exclusion_patterns = @state_exclusion_patterns
            change_tracking_settings.start_markers << /CITAC_RESOURCE_EXECUTION_START/
            change_tracking_settings.end_markers << /CITAC_RESOURCE_EXECUTION_END/
            change_tracking_settings.passthrough_output = options[:output] == :passthrough
            Citac::Utils::Serialization.write_to_file change_tracking_settings, settings_file

            puppets_opts = options.dup
            puppets_opts[:test_case_file] = test_case_file
            puppets_opts[:test_case_result_file] = test_case_result_file
            puppets_opts[:settings_file] = settings_file
            puppets_opts[:output] = :passthrough

            Citac::Integration::Puppet.apply @manifest_path, puppets_opts

            test_case_result = Citac::Utils::Serialization.load_from_file test_case_result_file
            test_case_result
          end
        end
      end
    end
  end
end