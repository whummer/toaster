require 'puppet/util/command_line'
require_relative 'patches/expanded_relationships_fix'
require_relative 'patches/graphml_generation'
require_relative 'patches/resource_execution_hook'
require_relative 'patches/resource_json_output'

module Citac
  module Puppet
    class CLI
      class << self
        def start(args)
          if args.size > 0 && args[0].start_with?('apply')
            args = args.dup
            args << '--detailed-exitcodes' unless args.include? '--detailed-exitcodes'

            if args[0] == 'apply-single'
              $citac_apply_single = true
              $citac_apply_single_resource_name = args[1]

              puts "Running only resource '#{$citac_apply_single_resource_name}'..."

              if args[2].downcase == '--trace'
                $citac_apply_single_trace = true
                $citac_apply_single_trace_file = args[3]

                args.delete_at 3
                args.delete_at 2

                puts "Tracing execution of '#{$citac_apply_single_resource_name}'..."
              end

              args[0] = 'apply'
              args.delete_at 1
            end

            begin
              run_puppet args
            rescue SystemExit => e
              exit 0 if e.status == 2
              exit e.status
            end
          else
            run_puppet args
          end
        end

        private

        def run_puppet(args)
          cmd = ::Puppet::Util::CommandLine.new 'puppet', args
          cmd.execute
        ensure
          raise $citac_error if $citac_error
        end
      end
    end
  end
end