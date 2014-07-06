#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "active_record"

module Toaster
  class KeyValuePair < ActiveRecord::Base
    self.inheritance_column = :type

    serialize :value, JSON

    def initialize(hash)
      if !hash[:type]
        type = IgnoreProperty.to_s
      end
      super(hash)
      @attributes_cache = {} if !@attributes_cache # fixes bug in active_record v4.1
    end

    def self.get_as_hash(list)
      attrs = {}
      list.each do |a|
        attrs[a.key] = a.value
      end
      return attrs
    end

    def self.from_hash(hash, clazz=KeyValuePair)
      result = []
      return result if !hash
      hash.each { |key,value|
        result << clazz.new(
          :key => key,
          :value => value
        )
      }
      return result
    end
    
    def to_s
      return "#{self.class}(#{key}=#{value})"
    end

    def hash
      begin
        return id if id
      rescue
      end
      h = 0
      h += key.hash rescue 0
      h += value.hash rescue 0
      h += type.hash rescue 0
      h += data_type.hash rescue 0
      return h
    end
    
  end
end
