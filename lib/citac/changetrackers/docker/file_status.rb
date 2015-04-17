module Citac
  module ChangeTrackers
    module Docker
      class FileStatus
        attr_reader :name, :size, :mode, :owner, :group

        def exists?
          @existing
        end

        def directory?
          @directory
        end

        def initialize(name, existing, size = nil, mode = nil, owner = nil, group = nil, directory = false)
          @name = name
          @existing = existing
          @size = size
          @mode = mode
          @owner = owner
          @group = group
          @directory = directory
        end

        def eql?(other)
          return true unless @existing || other.exists?
          return false unless @existing && other.exists?

          equal = @name == other.name && @mode == other.mode && @owner == other.owner && @group == other.group && @directory == other.directory?
          equal = equal && @size == other.size unless @directory

          equal
        end

        alias_method :==, :eql?

        def to_s
          mode_formatted = @mode ? "0#{@mode.to_s(8)}" : ''
          "#{@name}, exists: #{@existing}, directory: #{@directory}, size: #{@size}, mode: #{mode_formatted}, owner: #{@owner}, group: #{@group}"
        end
      end
    end
  end
end