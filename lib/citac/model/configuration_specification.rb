module Citac
  module Model
    class ConfigurationSpecification
      attr_reader :id, :name, :type, :type_metadata, :operating_systems

      def initialize(id, name, type, type_metadata, operating_systems)
        @id = id
        @name = name
        @type = type
        @type_metadata = type_metadata
        @operating_systems = operating_systems
      end

      def to_s
        id == name ? id : "#{name} (#{id})"
      end
    end

    class ConfigurationSpecificationRun
      attr_reader :id, :spec, :action, :operating_system, :exit_code, :start_time, :end_time, :duration

      def initialize(id, spec, action, operating_system, exit_code, start_time, end_time, duration)
        @id = id
        @spec = spec
        @action = action
        @operating_system = operating_system
        @exit_code = exit_code
        @start_time = start_time
        @end_time = end_time
        @duration = duration
      end
    end
  end
end