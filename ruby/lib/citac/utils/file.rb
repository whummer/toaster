module Citac
  module Utils
    module DirectoryTraversal
      def self.each_dir(root)
        paths = [root]
        while path = paths.shift
          if File.directory? path
            catch :prune do
              yield path

              Dir.entries(path).sort_by{|e| e.downcase}.reverse_each do |entry|
                next if entry == '.' || entry == '..'

                entry_path = File.join path, entry
                paths.unshift entry_path
              end
            end
          end
        end
      end

      def self.prune
        throw :prune
      end
    end
  end
end