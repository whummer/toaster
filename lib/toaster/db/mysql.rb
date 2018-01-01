

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster
  class MysqlDB < Toaster::DB
    
    # empty class. DB access handled by active_record gem

    def initialize(host = nil, port = nil, db = nil)
      db_host = host
      db_port = port
    end

  end
end
