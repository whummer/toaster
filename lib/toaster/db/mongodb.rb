

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'mongo'
require 'toaster/util/util'
require 'toaster/db/db'
require 'toaster/util/timestamp'

module Toaster
  class MongoDB < Toaster::DB

    attr_reader :connection, :db, :collection

    def save(hash_obj, id_fields = ["_id"])
      return find_or_update(hash_obj, id_fields, true)
    end

    def remove(criteria = {})
      @collection.remove(criteria)
    end

    def clear()
      # removing objects is not enough! (sequences still exist etc.)
      # remove_all()
      # --> delete and re-create the entire collection
      coll_name = @collection.name()
      @collection.drop()
      set_collection(coll_name)
    end
    def remove_all()
      @collection.remove()
    end

    def get_or_insert(hash_obj, id_fields = ["_id"])
      return find_or_update(hash_obj, id_fields, false)
    end

    def find(criteria = {})
      fix_db_object(criteria)
      #puts "DEBUG: Finding mongodb objects for criteria #{criteria.inspect}"
      result = @collection.find(criteria).to_a
      fix_db_object(result)
      result
    end
    def find_one(criteria)
      fix_db_object(criteria)
      #puts "DEBUG: Finding single mongodb object for criteria #{criteria.inspect}"
      result = @collection.find_one(criteria)
      fix_db_object(result)
      result
    end

    def count(criteria = {})
      fix_db_object(criteria)
      @collection.find(criteria).count()
    end

    def wrap_db_id(id)
      id = id["$oid"] if is_id_hash(id)
      BSON::ObjectId(id.to_s)
    end

    def find_or_update(hash_obj, id_fields = ["_id"], do_update = true)
      criteria = {}
      id_fields = [id_fields] if !id_fields.kind_of?(Array)
      id_fields.each do |f|
        criteria[f] = MongoDB.extract_by_expression(hash_obj, f)
      end
      if !do_update
        obj = @collection.find_one(criteria)
        #puts "Found object for criteria #{criteria.inspect}: #{obj}"
        if obj
          return obj
        end
      end
      upsert = true
      multi = false
      write_safe = 1
      @collection.update(criteria, hash_obj,
        {:upsert => upsert, :multi => multi, :w => write_safe})
      copy = @collection.find_one(criteria)
      return copy
    end

    def self.extract_by_expression(hash_obj, expression)
      expression = expression.dup
      expression.gsub!(/\.([0-9]+)\./, '[\1].')
      expression.gsub!(/\.([0-9]+)$/, '[\1]')
      expression.gsub!(/\.([a-zA-Z_0-9]+)\./, '[\'\1\'].')
      expression.gsub!(/\.([a-zA-Z_0-9]+)/, '[\'\1\']')
      expression.gsub!(/^([a-zA-Z_0-9]+)/, '[\'\1\']')
      cmd = "hash_obj#{expression}"
      result = nil
      begin
        result = eval(cmd)
      rescue => ex
        puts "Unable to evaluate expression: '#{cmd}' : #{ex}"
        raise ex
      end
      return result
    end

    def set_db(db_name)
      @db = @connection.db(db_name)
    end
    def set_collection(coll)
      @collection = @db.collection(coll)
    end

    def drop_collection(collection_name)
      coll = @db.collection(collection_name)
      if !coll
        raise "Unable to find DB collection named '#{collection_name}'"
      end
      coll.drop()
    end

    def repair_db()
      @db.command({"repairDatabase" => 1})
    end
    def compact_collections(colls=nil)
      colls = collections() if !colls
      colls.each do |coll|
        if coll != "system.indexes"
          puts "INFO: compacting collection #{coll}"
          @db.command({"compact" => coll})
        end
      end
    end

    def delete_backup(backup_collection_name)
      drop_collection(backup_collection_name)
    end

    def restore_backup(backup_collection_name, do_backup = true)
      # backup current DB state
      if do_backup
        backup()
      end
      # restore old state
      backup_coll = @db.collection(backup_collection_name)
      if !backup_coll
        raise "Unable to find DB collection named '#{backup_collection_name}'"
      end
      @collection.remove
      # clear cache
      Cache.clear()
      # copy database
      copy_db(backup_coll, @collection)
    end

    def backup(name = nil, coll = @collection)
      now = TimeStamp.now.to_i
      if !coll
        coll = @collection
      end
      if !name
        name = "#{coll.name}_bak_#{now}"
      end
      if name == coll.name
        raise "Cannot backup DB collection into itself. Please choose different name: '#{name}'."
      end
      coll_backup = @db.collection(name)
      copy_db(coll, coll_backup)
    end

    def transfer_data_to(host, port)
      transfer_data(host, port, @db.name(), @collection.name())
    end

    def transfer_data(to_host, to_port, to_db, to_collection, from_collection=@collection, from_db=nil, from_host=nil, from_port=nil)

      # check if we need to clear the cache at the end of the transfer operation
      do_clear_cache = Util.str_eql?(@connection.host,to_host) &&
          Util.str_eql?(@connection.port,to_port) &&
          Util.str_eql?(@db.name,to_db) &&
          Util.str_eql?(@collection.name,to_collection)

      from_conn = nil
      if from_collection.kind_of?(String)
        if from_host == to_host && from_port == to_port && from_db == to_db && from_collection == to_collection
          raise "ERROR: Cannot transfer database into itself: #{from_host}:#{from_port}::#{from_db}:#{from_collection}"
        end
        from_conn = Mongo::Connection.new(from_host, from_port, @connection_config)
        from_db = from_conn.db(from_db)
        from_collection = from_db.collection(from_collection)
      end
      to_conn = Mongo::Connection.new(to_host, to_port, @connection_config)
      to_db = to_conn.db(to_db)
      to_collection = to_db.collection(to_collection)
      copy_db(from_collection, to_collection)

      # close connections
      to_conn.close()
      from_conn.close() if from_conn
      # clear cache
      if do_clear_cache
        puts "DEBUG: Clearing cache after data transfer into currently active database."
        Cache.clear()
      end
    end

    def copy_db(from_collection, to_collection=nil)
      to_collection = @collection if !to_collection
      from_collection = @db.collection(from_collection) if from_collection.kind_of?(String)
      from_collection.find().each do |doc|
        to_collection.insert(doc) 
      end
    end

    def collection_exists?(name_pattern, collections_cache=nil)
      colls = collections(name_pattern, collections_cache)
      return colls && !colls.empty?
    end

    def collections(name_pattern=nil, collections_cache=nil)
      return get_collections(name_pattern, collections_cache)
    end
    def get_collections(name_pattern=nil, collections_cache=nil)
      name_pattern = /.*/ if !name_pattern
      if !collections_cache 
        collections_cache = @db.collections.collect { |c| c.name }
      end
      result = collections_cache.select { |c| c.match(name_pattern) }
      return result
    end

    def latest_collection(name_pattern)
      list = get_collections(name_pattern)
      return Util.latest_timestamp_item(list, name_pattern)
    end

    def get_backups()
      bak = @db.collections.select{ |c| c.name.include?("_bak_") }
      bak = bak.collect{ |c| 
        time = c.name.sub(/.*_bak_([0-9]+).*/, '\1').to_i
        { "name" => c.name, 
          "time" => time,
          "size" => @db.collection(c.name).size }
      }
      return bak
    end

    def get_testresult_collections()
      bak = @db.collections.select{ |c| c.name.match(/^test_/) }
      bak = bak.collect{ |c| 
        time = c.name.sub(/.*_([0-9]+)$/, '\1').to_i
        { "name" => c.name, 
          "time" => time, 
          "size" => @db.collection(c.name).size }
      }
      return bak
    end

    def fix_db_object(hash)
      if hash.kind_of?(Array)
        (1..(hash.size)).each do |i|
          v = hash[i-1]
          if is_id_hash(v)
            hash[i-1] = BSON::ObjectId(v["$oid"])
          else
            fix_db_object(v)
          end
        end
      elsif hash.kind_of?(Hash)
        # DO use .dup, otherwise we end up with an exception:
        # "hash modified during iteration (RuntimeError)"
        keys = hash.keys.dup
        keys.each do |k|
          v = hash[k]
          if is_id_hash(v)
            hash[k] = BSON::ObjectId(v["$oid"])
          else
            fix_db_object(v)
          end
        end
      end
    end

    private

    def initialize(host, port)
      @connection_config = {:pool_size => 10, :pool_timeout => 20}
      @connection = Mongo::Connection.new(host, port, @connection_config)
    end

    def is_id_hash(v)
      return false if !v.kind_of?(Hash) || v.size != 1 
      #oid = v["$oid"]
      #return oid && oid.kind_of?(String)
      return v["$oid"].kind_of?(String)
    end

  end
end
