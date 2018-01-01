

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/cache"

module Toaster
  class CachedDB

    def initialize(actual_db, config={})
      @db = actual_db
      @cache_result_lists = config["cache_result_lists"]
    end

    def find(criteria = {})
      if !@cache_result_lists
        return @db.find(criteria)
      end

      cached = Cache.by_obj_props(criteria)
      if cached
        #puts "DEBUG: Found cached object for criteria: #{criteria}"
        @db.fix_db_object(cached)
        return cached
      end

      obj = @db.find(criteria)
      Cache.set(obj)
      Cache.set(obj, [Cache::KEY_QUERIES, criteria.inspect])
      return obj
    end
    def find_one(criteria)
      cached = Cache.by_obj_props(criteria)
      if cached
        cached = [cached] if !cached.kind_of?(Array)
        @db.fix_db_object(cached)
        return cached[0] if cached.size == 1
      end

      obj = @db.find_one(criteria)
      Cache.set(obj)
      Cache.set(obj, [Cache::KEY_QUERIES, criteria.inspect])
      return obj
    end

    def method_missing(meth, *args, &block)
      @db.send(meth, *args, &block)
    end

  end
end
