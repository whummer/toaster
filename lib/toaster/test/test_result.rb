
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/timestamp"
require "toaster/util/util"

include Toaster

module Toaster
  class ResultEntry
    attr_accessor :name, :value
    def initialize(name=nil, value=nil)
      @name = name
      @value = value
    end
    def to_s
      result = "<entry>\n<name>#{name}</name>\n<value>#{value}</value>\n</entry>\n"
      return result
    end
  end

  class IterationResult
    attr_reader :entries
    def initialize
      @entries = []
    end
    def add(key, value)
      add_entry(key, value)
    end
    def add_entry(key, value)
      @entries << ResultEntry.new(key, value)
    end
    def to_s
      result = "<iterations>\n"
      entries().each do |e|
        result += e.to_s
      end
      result += "</iterations>\n"
      return result
    end
  end

  class TestResult
    attr_reader :iterations
    attr_accessor :start_time, :end_time
    def initialize
      @iterations = []
      start_time = TimeStamp.now.to_i
    end

    def new_iteration()
      i = IterationResult.new()
      @iterations << i
      return i
    end
    def save(file_path)
      content = to_s()
      Util.write(file_path, content, true)
    end

    def to_s
      result = "<genericTestResult>\n"
      @iterations.each do |i|
        result += i.to_s
      end
      result += "<startTime>#{start_time}</startTime>\n<finishTime>#{end_time}</finishTime>\n"
      result += "</genericTestResult>"
      return result
    end
  end
end
