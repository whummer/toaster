

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster

  class TransitionEdge 

    attr_accessor :node_from, :node_to, :disjunctive_conditions, :transition

    def initialize(node_from, node_to, conditions=[], transition=nil)
      @node_from = node_from
      @node_to = node_to
      @disjunctive_conditions = conditions
      @disjunctive_conditions = [] if !conditions
      @transition = transition
    end

    # each state transition represents the execution of an automation task
    def represented_task()
      t = @node_to.preceding_task()
      if @node_from.properties.include?("__task_num__") && @node_to.properties.include?("__task_num__")
        # in a "backwards" transition no particular task execution is represented
        if @node_from.properties["__task_num__"] > @node_to.properties["__task_num__"]
          return nil
        end
      end
      return t if t
      return @node_from.succeeding_task
    end

    def matches_parameters?(task_parameters)
      @disjunctive_conditions.each do |condition|
        all_contained = true
        condition.each do |key,value|
          contained = false
          task_parameters.each do |tp_key,tp_val|
            if key == tp_key
              if value.eql?(tp_val)
                contained = true
                break
              end
            end
          end
          if !contained
            all_contained = false
            break
          end
        end
        return true if all_contained
      end
      return false
    end

    def matches_states?(prestate, poststate)
      return false if !@node_from.subset_of?(prestate)
      return false if !@node_to.subset_of?(poststate)
      return true
    end

  end

end
