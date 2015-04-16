module Citac
  module Utils
    module System
      def self.hostname
        IO.read('/etc/hostname').strip
      end
    end
  end
end