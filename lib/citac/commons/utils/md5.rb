require_relative '../integration/md5sum'

module Citac
  module Utils
    module MD5
      def self.hash_files(files)
        Citac::Integration::Md5sum.hash_files files
      end
    end
  end
end