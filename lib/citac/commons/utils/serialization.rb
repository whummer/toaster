require 'yaml'

module Citac
  module Utils
    module Serialization
      def self.write_to_file(object, file_name)
        File.open file_name, 'w', :encoding => 'UTF-8' do |file|
          YAML.dump object, file
        end
      end

      def self.load_from_file(file_name)
        yaml = IO.read file_name, :encoding => 'UTF-8'
        YAML.load yaml
      end
    end
  end
end