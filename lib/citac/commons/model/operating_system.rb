module Citac
  module Model
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

      def specific?
        @version
      end

      def matches?(required_os)
        @name == required_os.name &&
            (required_os.version.nil? || @version == required_os.version)
      end

      def to_s
        @version ? "#{@name}-#{@version}" : "#{@name}-*"
      end

      def inspect
        to_s
      end

      def eql?(other)
        return false unless other
        @name == other.name && @version == other.version
      end

      alias_method :==, :eql?

      def debian_based?
        @name == 'debian' || @name == 'ubuntu'
      end
    end
  end
end