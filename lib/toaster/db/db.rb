

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/cached_db"
require "toaster/util/util"

module Toaster
  class DB

    class << self;
      attr_accessor :DEFAULT_HOST, :DEFAULT_PORT, :DEFAULT_DB, :DEFAULT_COLL, 
        :IMPL_CLASSES, :USE_CACHE, :DEFAULT_REQUIRE, :DEFAULT_TYPE, :REQUIRE_PATH
    end
    @DEFAULT_HOST = "localhost"
    @DEFAULT_PORT = 27017
    @DEFAULT_DB = "toaster"
    @DEFAULT_COLL = "toaster" 
    @DEFAULT_TYPE = "mongodb"

    @REQUIRE_PATH = "toaster/db/"
    @IMPL_CLASSES = { "mongodb" => "Toaster::MongoDB" }
    @USE_CACHE = false

    @@instance = nil

    def self.instance(host = nil, port = nil, db = nil, collection = nil, type = nil)
      host = self.DEFAULT_HOST if Util.empty?(host)
      port = self.DEFAULT_PORT if Util.empty?(port)
      db = self.DEFAULT_DB if Util.empty?(db)
      collection = self.DEFAULT_COLL if Util.empty?(collection)
      type = self.DEFAULT_TYPE if Util.empty?(type)

      @@instances ||= {}
      key = get_key(type, host, port, db, collection)
      return @@instances[key] if @@instances[key]

      #puts "Using DB connection #{host}:#{port}, db '#{db}', collection '#{collection}'"

      init_instance(type, host, port, db, collection)
    end

    def self.apply_values(object, hash)
      return object if !hash
      vars = object.instance_variables
      hash.each do |k,v|
        writer_method = "#{k}="
        if object.respond_to?(writer_method.to_sym)
          begin
            #puts "Applying value object.#{k} = #{v}"
            # object.send(..) is possibly a bit faster than eval(..)
            object.send(writer_method.to_sym, v)
            # eval("object.#{k} = v")
          rescue => ex
            puts "Unable to set variable: object.#{k} = 'v' : #{ex}"
          end
        end
      end
      return object
    end

    private

    def self.init_instance(type, host, port, db, collection)
      # setup default instance

      key = get_key(type, host, port, db, collection)

      clazz = DB.IMPL_CLASSES[type]

      #puts "#{host} - #{port} - #{db} - #{collection} - #{type}"

      require "#{DB.REQUIRE_PATH}/#{type}"

      @@instances[key] = eval(clazz).new(host, port)
      @@instances[key].set_db(db)
      @@instances[key].set_collection(collection)
      if DB.USE_CACHE
        cache_config = DB.USE_CACHE
        @@instances[key] = CachedDB.new(@@instances[key], cache_config)
      end
      return @@instances[key]
    end

    def self.get_key(type, host, port, db, collection)
      return "#{host}:#{port} - #{db}:#{collection} - cached:#{DB.USE_CACHE}"
    end

  end
end
