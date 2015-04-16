module Citac
  module Integration
    module Strace
      class Syscall
        NAME_EXP = /^([0-9]+\s+)?(?<name>[a-z0-9_]+)\(/i
        QUOTED_ARG_EXP = /"(?<value>([^"\\]|\\.)*)"/
        FD_EXP = /\d+<(?<value>[^>]+)>/
        PIPE_EXP = /^pipe:\[\d+\]$/

        attr_reader :line, :name

        def initialize(line)
          @line = line.strip
          @name = parse_name
        end

        def quoted_arguments
          @quoted_args ||= @line.scan(QUOTED_ARG_EXP).map(&:first)
        end

        def file_descriptors
          @file_descriptors ||= @line.scan(FD_EXP).map(&:first).reject{|f| f =~ PIPE_EXP}
        end

        def non_existing_file?
          @line =~ /\)\s+=\s+-1\s+ENOENT/
        end

        private

        def parse_name
          match = NAME_EXP.match @line
          raise "Failed to parse syscall line for name: '#{@line}'" unless match

          match[:name]
        end
      end
    end
  end
end