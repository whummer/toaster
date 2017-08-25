require_relative './filesystem'
require 'toaster/util/config'

module Citac
  module Data
    class DatabaseSpecificationRepository < Citac::Data::FileSystemSpecificationRepository

      def initialize(root)
        @root = File.expand_path root
        Toaster::Config.init_db_connection
      end

      def each_spec
        require 'rails/all'
        require 'toaster/model/automation'

        list = Toaster::Automation.find()
        list.each { |spec|
          yield spec
        }
      end
    end
  end
end