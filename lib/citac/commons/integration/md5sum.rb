require_relative '../utils/exec'

module Citac
  module Integration
    module Md5sum
      def self.hash_files(files)
        files = [files] unless files.respond_to? :each

        escaped_file_names = files.map { |f| f.gsub ' ', '\ ' }.to_a
        result = Citac::Utils::Exec.run 'xargs -n 100 md5sum', :stdin => escaped_file_names
        parse_output result.output
      end

      def self.parse_output(output)
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