
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster

  class StateChange < ActiveRecord::Base
    # attr_accessor :property, :action, :value, :old_value, :task_execution

    ACTION_INSERT = "insert"
    ACTION_MODIFY = "modify"
    ACTION_DELETE = "delete"
    ACTION_UNKNOWN = "unknown"
    VALUE_UNKNOWN = nil

    belongs_to :task_execution

    def initialize1(property=nil, action=nil, value=nil, old_value=nil)
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

    def ==(obj)
      return eql?(obj)
    end

    def eql?(obj)
      return obj.kind_of?(StateChange) && 
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
