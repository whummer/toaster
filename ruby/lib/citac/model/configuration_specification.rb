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
  end
end