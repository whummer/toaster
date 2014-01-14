
require 'toaster/util/logging'

# update Waldemar Hummer:
# the requires below are required, otherwise we get:
# uninitialized constant RubyLexer::RubyParserStuff
# [...]/ruby_parser-3.1.1/lib/ruby_lexer.rb:241
require 'ruby_lexer'
require 'ruby_parser_extras'
class RubyLexer
  begin
    #RubyParserStuff = Kernel.const_get("RubyParserStuff")
  rescue Object => exc
    begin
      RubyParserStuff = ::RubyParserStuff
    rescue Object => exc1
      puts "WARN: Unable to load the module 'RubyParserStuff' into class RubyLexer"
    end
  end
end

require 'json'

module Toaster

  # Enhanced, recursive mini-DSL processor which is able to parse multi-level 
  # nested Chef attributes, e.g., default['apache']['worker']['startservers'] = 4
  # 
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  class DefaultProcessorRecursive < Hash # :nodoc:
    def initialize(node_values = {}, &error_reporting)
      @user_values = Hash.new.merge(node_values) if node_values
      @error_reporting = error_reporting
    end
    def default(arg = nil)
      if arg
        if !self.include?(arg)
          store(arg, self.class.new)
        end
        return self[arg]
      end
      return self
    end
    def set(arg = nil)
      if arg
        store(arg, self.class.new)
        return self[arg]
      end
      return self
    end
    def node(arg = nil)
      new_hash = self.class.new
      new_hash.merge!(@user_values["node"]) if @user_values["node"]
      return new_hash
    end
    def attribute?(arg)
      return !@user_values[arg].nil?
    end
    def method_missing(sym, *arguments, &block)
      if ["platform", "platform_version", "ipaddress", "fqdn", 
        "macaddress", "hostname", "domain", "recipes", "roles", 
        "ohai_time", "kernel", "cpu"].include?(sym.to_s)
        value = @user_values[sym.to_s]
        if !value && @error_reporting
          @error_reporting.call(Logger::WARN, "No value for Chef node attribute '#{sym.to_s}'. Please provide a value in the chef_node_inspector configuration.")
        end
        return value
      else
        raise "Missing method #{sym} when trying to parse Chef node attributes"
      end
    end
  end

  class ChefNodeInspector

    @@DEFAULT_PROCESSOR_CLASS = Toaster::DefaultProcessorRecursive

    @processor = nil
    
    attr_writer :keyfile

    private

    # Format of a Recipe name      
    RECIPE_REGEXP = /([a-z_A-Z0-9]+)(::([a-z_A-Z0-9]+))?/

    public
    
    # * chef_paths - Chef dirs on local filesystem
    def initialize(chef_paths, processor = nil, &error_reporting)
      @chef_paths = chef_paths
      @processor = processor
      raise "Invalid 'error_reporting'" if error_reporting.nil?
      @error_reporting = error_reporting
      @keyfile = nil
    end

    # scrape the default param files and return recipe -> param -> default
    def get_defaults(cookbook_name, recipe_name="default")
      if cookbook_name.nil?
        @error_reporting.call(Logger::WARN, "Unknown cookbook #{cookbook_name.inspect}")
        return {}
      end
      
      default_file = get_filename("cookbooks/" + cookbook_name + "/attributes/#{recipe_name}.rb")

      if default_file.nil?
        @error_reporting.call(Logger::INFO, "Unknown default file #{("cookbooks/" + cookbook_name + "/attributes/#{recipe_name}.rb").inspect}")
        return {}
      end
      
      default_processor = @processor.nil? ? DefaultProcessorRecursive.new() : @processor
      begin
        default_processor.instance_eval(File.new(default_file).read(), default_file)
      rescue NoMethodError => e
        @error_reporting.call(Logger::WARN, "#{e.to_s}\n#{e.backtrace.join("\n")}")
        return {}
      end
      
      return default_processor.default()
    end

    def get_cookbooks(recipes)
      return recipes.map { |qualified_recipe| qualified_recipe[RECIPE_REGEXP, 1] }.uniq
    end

    private

    def get_filename(filename)
      @chef_paths.each do |path|
        candidate = File.expand_path(filename, path)
        return candidate if File.exist?(candidate)
      end
      
      # No such file
      @@logger.info "File not found '#{filename}'"
      return nil
    end

  end 

end
