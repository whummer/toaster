require_relative '../../utils/graph'

module Citac
  module Puppet
    module Utils
      module TraceParser
        class ResourceTrace
          attr_reader :resource_name, :syscalls

          def failed?; !@successful; end
          def successful?; @successful; end

          def initialize(resource_name, successful, syscalls)
            @resource_name = resource_name
            @successful = successful
            @syscalls = syscalls
          end

          def to_h
            {
                :resource_name => @resource_name,
                :successful => @successful,
                :syscalls => @syscalls
            }
          end
        end

        def self.parse_file(file_name)
          File.open file_name do |f|
            parse f
          end
        end

        def self.parse(io)
          start_exp = /CITAC_RESOURCE_EXECUTION_START:(?'resource_name'[a-f0-9]+):/
          end_exp = /CITAC_RESOURCE_EXECUTION_END:(?'status'[^:]+):/

          result = []
          syscalls = Hash.new {|h,k| h[k] = []}
          current_resource = nil

          io.each_line do |line|
            if current_resource

              match = end_exp.match line
              if match
                successful = match[:status].downcase == 'true'
                result << ResourceTrace.new(current_resource, successful, syscalls[current_resource])

                current_resource = nil
              else
                syscalls[current_resource] << line.strip
              end
            else
              match = start_exp.match line
              if match
                current_resource = match[:resource_name]
                current_resource = current_resource.scan(/../).map { |x| x.hex }.pack('c*')
                current_resource.force_encoding 'UTF-8'
              end
            end
          end

          result
        end
      end
    end
  end
end