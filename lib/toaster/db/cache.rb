

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

module Toaster
  class Cache

    KEY_OBJECTS = "__objects__"
    KEY_QUERIES = "__queries__"

    @@active_cache = nil

    def by_db_type(db_type)
      # should be overwritten by subclasses
    end

    def by_id(id)
      # should be overwritten by subclasses
    end

    def by_key(key)
      load_cache()
    end

    def set(value, key=KEY_OBJECTS)
      # should be overwritten by subclasses
    end

    def by_obj_props(props_hash)
      # should be overwritten by subclasses
    end

    def clear()
      # should be overwritten by subclasses
    end

    def flush()
      # should be overwritten by subclasses
    end

    def get_hits()
      # should be overwritten by subclasses
    end

    def get_misses()
      # should be overwritten by subclasses
    end



    def self.by_obj_props(props_hash)
      return @@active_cache.by_obj_props(props_hash) if @@active_cache
    end

    def self.by_db_type(db_type)
      return @@active_cache.by_db_type(db_type) if @@active_cache
    end

    def self.by_id(id)
      return @@active_cache.by_id(id) if @@active_cache
    end

    def self.by_key(key)
      return @@active_cache.by_key(key) if @@active_cache
    end

    def self.set(value, key=KEY_OBJECTS)
      return @@active_cache.set(value, key) if @@active_cache
    end

    def self.set_cache(cache)
      @@active_cache = cache
    end

    def self.get_cache()
      @@active_cache
    end

    def self.get_hits()
      return @@active_cache.get_hits() if @@active_cache
    end

    def self.get_misses()
      return @@active_cache.get_misses() if @@active_cache
    end

    def self.clear()
      @@active_cache.clear() if @@active_cache
    end

    def self.flush()
      @@active_cache.flush() if @@active_cache
    end

  end
end
