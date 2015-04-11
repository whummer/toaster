require_relative 'exec'

module Citac
  module Utils
    module MD5
      def self.hash_files(files)
        #TODO split into multiple calls or do it with stdin / xargs
        files = [files] unless files.respond_to? :each

        result = Citac::Utils::Exec.run 'md5sum', :args => files
        parse_md5sum_output result.output
      end

      def self.parse_md5sum_output(output)
        result = Hash.new

        output.each_line do |line|
          line = line.strip
          hash = line[0..31].downcase
          file_name = line[32..-1].strip

          result[file_name] = hash
        end

        result
      end
    end
  end
end