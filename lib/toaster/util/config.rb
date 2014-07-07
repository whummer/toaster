
####################################################
# (c) Waldemar Hummer (hummer@infosys.tuwien.ac.at)
####################################################

require 'json'
require 'toaster/markup/markup_util'

module Toaster
    
  #
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  #

  class Config

    @dns_suffix = "us.to"

    class << self
      attr_accessor :values, :dns_suffix
    end

    def self.host(subdomain="toaster")
      "#{subdomain}.#{dns_suffix}"
    end

    @values = {}
    @values["db"] = {"host" => host("toaster")}

    def self.set(key,value, v=values)
      parts = key.split(".")
      last_key = parts.pop # remove last key from array
      parts.each do |p|
        if !v[p]
          v[p] = {}
        end
        v = v[p]
      end
      v[last_key] = value
    end
    def self.get(key, v=values)
      parts = key.split(".")
      last_key = parts.pop # remove last key from array
      parts.each do |p|
        if !v[p]
          v[p] = {}
        end
        v = v[p]
      end
      v[last_key]
    end

    def self.init_db_connection(config=nil)
      require "toaster/util/util"
      if !config
        config = {
          "db_type" => "mysql", 
          'mysql' => Config.get('db')
        }
      end
      if config["db_type"] == "mysql" && config["mysql"]
        require "active_record"
        ActiveRecord::Base.establish_connection(
          :adapter => 'mysql2',
          :host => config["mysql"]["host"],
          :database => config["mysql"]["database"],
          :username => config["mysql"]["username"],
          :password => config["mysql"]["password"]
        )
      else
        puts "WARN: Incorrect database connection configuration"
      end
    end

    private

    def self.read_files() 
      found = false
      (1..4).each do |num_dirs|
        config_dir = File.join(File.dirname(__FILE__), Array.new(num_dirs, "..").join("/"))
        #puts "DEBUG: Searching for config in directory #{config_dir}"
        file = File.expand_path(File.join(config_dir, "config.json"))
        if File.exist?(file)
          found = true
          if ARGV.include?("-v")
            puts "DEBUG: Reading configuration values from file '#{file}'"
          end
          MarkupUtil.rmerge!(@values, JSON.parse(File.read(file)))
        end
      end
      if !found
        puts "WARN: No configuration file 'config.json' found."
      end
      file = File.expand_path(File.join(Dir.home, ".toaster"))
      if File.exist?(file)
        if ARGV.include?("-v")
          puts "DEBUG: Reading configuration values from file '#{file}'"
        end
        MarkupUtil.rmerge!(@values, JSON.parse(File.read(file)))
      end
    end

    read_files()

  end
end
