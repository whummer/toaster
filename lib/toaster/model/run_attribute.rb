#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/model/key_value_pair"

module Toaster
  class RunAttribute < KeyValuePair

    belongs_to :automation_run

    def self.from_hash(hash)
      super(hash, RunAttribute)
    end

  end
end
