module Citac
  module Data
    class OperatingSystem
      def self.parse(os_string)
        pieces = os_string.split '-', 2
        OperatingSystem.new pieces[0], pieces[1]
      end

      attr_reader :name, :version

      def initialize(name, version)
        @name = name
        @version = version
      end

      def to_s
        @version ? "#{@name}-#{@version}" : "#{@name}-*"
      end

      def inspect
        to_s
      end
    end

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