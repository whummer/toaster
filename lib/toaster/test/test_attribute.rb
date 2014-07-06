

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

include Toaster

module Toaster
  class TestAttribute < KeyValuePair

    belongs_to :test_case

    def self.from_hash(hash)
      super(hash, TestAttribute)
    end

  end
end
