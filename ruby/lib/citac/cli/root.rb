require 'thor'

require_relative 'puppet'
require_relative '../specification/parser'

module Citac
  module CLI
    class CitacCLI < Thor
      desc 'puppet <command> <args...>', 'Puppet specific commands'
      subcommand 'puppet', Puppet

      desc 'graph specfile [--png pngfile]', 'Generates a Graphviz graph of the given configuration specification'
      option :png
      def graph(specfile, pngfile = nil)
        spec = File.open(specfile) { |f| ConfigurationSpecification.parse f }
        g = spec.to_graph

        if options[:png] && pngfile
          IO.popen('dot -Tpng', 'rb+') do |dot|
            dot.puts g
            dot.close_write

            buf = ''
            File.open(pngfile, 'wb') do |f|
              while dot.read(1024, buf)
                f.write buf
              end
            end
          end
        else
          puts g
        end
      end
    end
  end
end