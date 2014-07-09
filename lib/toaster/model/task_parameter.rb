

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/model/key_value_pair"

module Toaster
  class TaskParameter < KeyValuePair

    @@id_attributes = ["task_id", "key", "value", "type"]

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      super(attr_hash)
    end

    def self.find(criteria={}, preset_fields={})
      criteria["db_type"] = "task_parameter" if !criteria["db_type"]
      objs = []
      DB.instance.find(criteria).each do |hash|
        task = preset_fields.include?("task") ? preset_fields["task"] :
              Task.load(run_hash["task_id"])
        obj = TaskParameter.new(task, nil)
        objs << DB.apply_values(obj, hash)
      end
      return objs
    end

    def self.load(uuid_or_task, key = nil, value = nil, type = nil, constraints = [])
      param = TaskParameter.new(nil, nil)
      hash = {}
      if !uuid_or_task.kind_of?(Task)
        uuid = uuid_or_task
        return nil if !uuid
        criteria = {"uuid" => uuid, "db_type" => "task_parameter"}
        hash = DB.instance.find_one(criteria)
      else
        task = uuid_or_task
        param = TaskParameter.new(task, key, value, type, constraints)
        hash = DB.instance.get_or_insert(param.to_hash(), @@id_attributes)
      end
      param = DB.apply_values(param, hash)
      return param
    end

    def hash
      h = @key.hash
      h += @value.hash if @value
      h += @type.hash if @type
      h += @constraints.hash if @constraints
      return h
    end

    def eql?(obj)
      return obj.kind_of?(TaskParameter) && obj.key == @key && obj.value == @value && 
              obj.type == @type && obj.constraints == @constraints
    end

  end
end
