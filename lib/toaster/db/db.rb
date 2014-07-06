

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/cached_db"
require "toaster/util/util"

module Toaster

  # TODO deprecated, remove?

  class DB

    class << self;
      attr_accessor :DEFAULT_HOST, :DEFAULT_PORT, :DEFAULT_DB, :DEFAULT_COLL, 
        :IMPL_CLASSES, :USE_CACHE, :DEFAULT_REQUIRE, :DEFAULT_TYPE, :REQUIRE_PATH
    end
    @DEFAULT_HOST = "localhost"
    @DEFAULT_PORT = 27017
    @DEFAULT_DB = "toaster"
    @DEFAULT_TYPE = "mysql"

    @REQUIRE_PATH = "toaster/db/"
    @IMPL_CLASSES = { 
      "mongodb" => "Toaster::MongoDB",
      "mysql" => "Toaster::MysqlDB"
    }
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

    def self.find_activerecord(clazz, criteria)
      if criteria.kind_of?(String)
        criteria = criteria.to_i
      end
      if numeric?(criteria)
        return clazz.find_by(:id => criteria)
      elsif !criteria || criteria.empty?
        return clazz.all
      else
        return clazz.where(criteria)
      end
    end

    attr_accessor :db_host, :db_port, :db_name, :db_collection

    private

    def self.numeric?(str)
      return true if str =~ /^\d+$/
      true if Float(str) rescue false
    end

    def self.init_instance(type, host, port, db, collection)
      # setup default instance

      key = get_key(type, host, port, db, collection)

      clazz = DB.IMPL_CLASSES[type]

      #puts "#{host} - #{port} - #{db} - #{collection} - #{type}"

      require "#{DB.REQUIRE_PATH}/#{type}"

      @@instances[key] = eval(clazz).new(host, port)
      @@instances[key].db_name = db
      @@instances[key].db_collection = collection
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
