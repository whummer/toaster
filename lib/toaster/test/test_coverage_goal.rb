

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "active_record"

include Toaster

module Toaster

  class CombinationCoverage
    SKIP_N = 1
    SKIP_N_SUCCESSIVE = 2
    COMBINE_N = 3
    COMBINE_N_SUCCESSIVE = 4
  end

  class StateGraphCoverage
    STATES = 1
    TRANSITIONS = 2
    TRANSITION_PAIRS = 3
    FULL_SEQUENCE = 4
  end

  class TestCoverageGoal < ActiveRecord::Base
    #attr_accessor :idempotence, :combinations, :repeat_N, :optimize_for_rendering, :graph, :only_connect_to_start
    attr_accessor :optimize_for_rendering

    serialize :idempotence, JSON
    serialize :combinations, JSON

    def initialize(attr_hash={})
      if !attr_hash
        attr_hash = {}
      end
      super(attr_hash)
      init()
    end

    def self.create(idempotence_N=0, 
          skip_N=[], skip_N_successive=[], 
          combine_N=[], combine_N_successive=[], 
          graph_coverage = StateGraphCoverage::STATES,
          only_connect_to_start = true
      )
      tcg = TestCoverageGoal.new
      tcg.init(idempotence_N, skip_N, skip_N_successive,
        combine_N, combine_N_successive, graph_coverage,
        only_connect_to_start)
      return tcg
    end

    def init(idempotence_N=0, 
          skip_N=[], skip_N_successive=[], 
          combine_N=[], combine_N_successive=[], 
          graph_coverage = StateGraphCoverage::STATES,
          only_connect_to_start = true
      )
      tcg = self
      tcg.idempotence = idempotence_N
      tcg.combinations = {
        CombinationCoverage::SKIP_N => skip_N ? skip_N : [],
        CombinationCoverage::SKIP_N_SUCCESSIVE => skip_N_successive ? skip_N_successive : [],
        CombinationCoverage::COMBINE_N => combine_N ? combine_N : [],
        CombinationCoverage::COMBINE_N_SUCCESSIVE => combine_N_successive ? combine_N_successive : []
      }
      tcg.graph = graph_coverage ? graph_coverage : StateGraphCoverage::STATES
      tcg.only_connect_to_start = only_connect_to_start
      tcg.repeat_N = 1
      tcg.optimize_for_rendering = false
    end
    def set_only_connect_to_start(do_only_connect_to_start)
      only_connect_to_start = do_only_connect_to_start
      return self
    end
    def set_repeat_N(repeat_N)
      repeat_N = repeat_N
      return self
    end
#    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
#      return {
#        "idemN" => @idempotence,
#        "comb" => {
#          "c#{CombinationCoverage::SKIP_N}" => @combinations[CombinationCoverage::SKIP_N],
#          "c#{CombinationCoverage::SKIP_N_SUCCESSIVE}" => @combinations[CombinationCoverage::SKIP_N_SUCCESSIVE],
#          "c#{CombinationCoverage::COMBINE_N}" => @combinations[CombinationCoverage::COMBINE_N],
#          "c#{CombinationCoverage::COMBINE_N_SUCCESSIVE}" => @combinations[CombinationCoverage::COMBINE_N_SUCCESSIVE]
#        },
#        "graph" => @graph,
#        "only_connect_to_start" => @only_connect_to_start
#      }
#    end
#    def self.from_hash(hash)
#      return TestCoverageGoal.new(
#        hash["idemN"], 
#        hash["comb"]["c#{CombinationCoverage::SKIP_N}"],
#        hash["comb"]["c#{CombinationCoverage::SKIP_N_SUCCESSIVE}"],
#        hash["comb"]["c#{CombinationCoverage::COMBINE_N}"],
#        hash["comb"]["c#{CombinationCoverage::COMBINE_N_SUCCESSIVE}"],
#        hash["graph"],
#        hash["only_connect_to_start"]
#      )
#    end
  end

end
