

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

include Toaster

module Toaster

  class StateTransition

    attr_accessor :pre_state, :parameters, :post_state

    def initialize(pre_state={}, parameters={}, post_state={})
      @pre_state = pre_state
      @parameters = parameters
      @post_state = post_state
    end

    def eql?(obj)
      return false if !obj.kind_of?(StateTransition)
      return obj.pre_state.eql?(@pre_state) && 
              obj.parameters.eql?(@parameters) && 
              obj.post_state.eql?(@post_state)
    end

    def ==(obj)
      return eql?(obj)
    end

    def hash()
      return @pre_state.hash + @parameters.hash + @post_state.hash
    end

  end

end
