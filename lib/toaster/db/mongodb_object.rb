

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#
module Toaster
  class MongoDBObject

    attr_accessor :_id, :db_type

    def initialize
      @_id = ""
      @db_type = self.class.name
    end

    def id
      return @_id
    end

    def save(id_fields = [])
      db = DB.instance
      hash = to_hash
      obj = db.save(hash, id_fields)
      @_id = obj[:_id] ? obj[:_id] : obj["_id"]
      return self
    end

    def delete()
      if !id || id.to_s.strip == ""
        puts "WARN: Unable to delete DB object with empty id: #{self}"
        return false
      end
      DB.instance.remove({"_id" => id})
      return true
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      return MongoDBObject.to_hash(self, exclude_fields,additional_fields,recursion_fields)
    end

    def self.to_hash(obj, exclude_fields = [], additional_fields = {}, recursion_fields = [])
      hash = {}
      obj.instance_variables.each {|var| 
        k = var.to_s.delete("@")
        if !exclude_fields.include?(k) && obj.respond_to?(k)
          hash[k] = obj.instance_variable_get(var)
          if recursion_fields.include?(k)
            if hash[k].kind_of?(Array)
              copy = hash[k]
              hash[k] = []
              copy.each do |item|
                hash[k].push(item.to_hash)
              end
            else
              hash[k] = hash[k].to_hash
            end
          end
        end
      }
      additional_fields.each do |k,v|
        hash[k] = v
      end
      hash
    end

    def self.list_include?(haystack, needle, property_method = :id)
      raise "Object to search is not a DB object, does not respond to '#{property_method}' method" if !needle.respond_to?(property_method)
      needle_prop = needle.send(property_method)
      haystack.each do |obj|
        raise "Object in list is not a DB object, does not respond to '#{property_method}' method" if !obj.respond_to?(property_method)
        obj_prop = obj.send(property_method)
        return true if obj == needle
        return true if obj_prop == needle_prop
      end
      return false
    end

  end
end
