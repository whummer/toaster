module Citac
  module Utils
    module Processes
      class ProcessData
        attr_reader :pid, :name, :uid, :cmdline

        def initialize(pid, name, uid, cmdline)
          @pid = pid
          @name = name
          @uid = uid
          @cmdline = cmdline
        end
      end

      def self.list
        processes = []
        each {|p| processes << p}
        processes
      end

      def self.each
        Dir.foreach '/proc' do |dir|
          next unless dir =~ /^[0-9]+$/

          pid = dir.to_i

          properties = Hash.new
          status_lines = IO.readlines "/proc/#{pid}/status"
          status_lines.map{|l| l.strip.split /:\s+/, 2}.each do |name, value|
            properties[name.downcase] = value
          end

          name = properties['name']
          uid = properties['uid'].split(/\s+/).first.to_i
          cmdline = IO.read("/proc/#{pid}/cmdline").split("\0").join(' ').strip

          yield ProcessData.new(pid, name, uid, cmdline)
        end
      end
    end
  end
end