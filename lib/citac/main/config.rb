module Citac
  module Config
    class << self
      def base_dir
        File.absolute_path '../../..', File.dirname(__FILE__)
      end

      def spec_dir
        File.join base_dir, 'var', 'specs'
      end

      def cache_dir
        File.join base_dir, 'var', 'cache'
      end
    end
  end
end