

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster

  class State
    attr_accessor :properties
  end

  class StateProperty
    attr_accessor :key, :value
  end

  class StatePropertyChange
    attr_accessor :property, :action, :value, :old_value, :task_execution

    ACTION_INSERT = "insert"
    ACTION_MODIFY = "modify"
    ACTION_DELETE = "delete"
    ACTION_UNKNOWN = "unknown"
    VALUE_UNKNOWN = nil

    def initialize(property=nil, action=nil, value=nil, old_value=nil)
      @property = property
      @action = action
      @value = value
      @old_value = old_value
      @task_execution = nil
    end

    def to_s
      if action == ACTION_MODIFY
        return "Modification of property '#{property}': '#{old_value}' --> '#{value}'"
      elsif action == ACTION_DELETE
        return "Deletion of property '#{property}'"
      elsif action == ACTION_INSERT
        return "Insertion of property '#{property}': '#{value}'"
      end
      return "Action '#{@action}' on property '#{property}', value='#{value}', old_value='#{old_value}'"
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      exclude_fields << "task_execution" if !exclude_fields.include?("task_execution")
      return MongoDBObject.to_hash(self, exclude_fields)
    end

    def is_delete?()
      return action == ACTION_DELETE
    end
    def is_modify?()
      return action == ACTION_MODIFY
    end
    def is_insert?()
      return action == ACTION_INSERT
    end

    def self.from_hash_array(prop_change_array)
      prop_changes = []
      prop_change_array.each do |pc|
        prop_changes << from_hash(pc)
      end
      return prop_changes
    end

    def self.from_hash(prop_change)
      p = StatePropertyChange.new
      p.property = prop_change["property"]
      p.action = prop_change["action"]
      p.value = prop_change["value"] if prop_change["value"]
      p.old_value = prop_change["old_value"] if prop_change["old_value"]
      return p
    end

    def ==(obj)
      return eql?(obj)
    end

    def eql?(obj)
      #puts "property: #{obj.property} - #{@property}" if obj.property != @property
      #puts "action: #{obj.action} - #{@action}" if obj.action != @action
      #puts "old_value: #{obj.old_value} - #{@old_value}" if obj.old_value != @old_value
      #puts "value: #{obj.value} - #{@value}" if obj.value != @value
      return obj.kind_of?(StatePropertyChange) && 
        obj.property == @property && obj.action == @action && 
        obj.value == @value && obj.old_value == @old_value
    end

    def hash
      h = 0
      h += @property.hash if @property
      h += @value.hash if @value
      h += @action.hash if @action
      h += @old_value.hash if @old_value
      return h
    end

  end

end
