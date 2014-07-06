#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/model/key_value_pair"

module Toaster
  class AutomationAttribute < KeyValuePair

    belongs_to :automation

  end
end
