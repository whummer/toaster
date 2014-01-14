
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

  # mini-DSL to parse a default file
  class DefaultProcessor # :nodoc:
    # We evaluate the default.rb file expecting the values to be mostly constants, we might produce
    # invalid results for complex defaults such as
    #    default['jke']['db_hostname'] = ENV['HOSTNAME'] || "localhost"
    def initialize
      # The following Ruby notation creates a special kind of Hash that automatically creates
      # a child Hash if we ask about a key, and the child hash automatically creates a nil entry
      # if we ask about keys.
      @defaults = Hash.new { |h,k| h[k] = Hash.new { |h2, k2| h2[k2] = nil } }
    end
    
    def default
      return @defaults
    end
    
    def method_missing(sym, *arguments, &block)
      return FailureEater.new(sym)
    end
  end

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


  #
  # Introspects \Chef role files.   
  #
  class ChefNodeInspector

    @@DEFAULT_PROCESSOR_CLASS = Toaster::DefaultProcessor

    @processor = nil
    
    attr_writer :keyfile

    private
    
    # :stopdoc:
    # Format of a Recipe name      
    RECIPE_REGEXP = /([a-z_A-Z0-9]+)(::([a-z_A-Z0-9]+))?/
    # :startdoc:
    
    public
    
    # * +chef_paths+ - \Chef directories on local filesystem
    # * +error_reporting+ - a <code>Proc { |level, message| }</code> for reporting progress.
    def initialize(chef_paths, processor = nil, &error_reporting)
      @chef_paths = chef_paths
      @processor = processor
      raise "Invalid 'error_reporting'" if error_reporting.nil?
      @error_reporting = error_reporting
      @keyfile = nil
    end

    # Given a \Chef cookbook name, scrape the default parameter files and return a Hash of Hashes, recipe->param->default
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
      
      default_processor = @processor.nil? ? DefaultProcessor.new() : @processor
      begin
        default_processor.instance_eval(File.new(default_file).read(), default_file)
      rescue NoMethodError => e
        @error_reporting.call(Logger::WARN, "#{e.to_s}\n#{e.backtrace.join("\n")}")
        return {}
      end
      
      return default_processor.default()
    end

    # Given an array of fully-qualified recipes, get a list of cookbooks needed by those recipes
    def get_cookbooks(recipes)
      return recipes.map { |qualified_recipe| qualified_recipe[RECIPE_REGEXP, 1] }.uniq
    end
    
    # Given an array of fully-qualified recipes, get a list of Ruby .rb files that implement those recipes
    def get_relative_recipe_files(recipes)
      return recipes.map { |qualified_recipe| [qualified_recipe[RECIPE_REGEXP, 1], qualified_recipe[RECIPE_REGEXP, 3] || 'default'] }.
      map { |cookbook, recipe| "cookbooks/" + cookbook.to_s + '/recipes/' + recipe.to_s + '.rb' }
    end
    # :startdoc:

    private

    # Return the filename relative to 'dir'
    def relativize(filename, dir)
      dirname = File.expand_path(dir) + '/'
      prefix = ''
      while dirname
        dirname = '/' if dirname == '//'
        startswith = Regexp.new("^#{dirname}(.*)").match(filename)
        #puts "dirname=#{dirname}, prefix=#{prefix}, startswith=#{startswith}"
        return "#{prefix}#{startswith[1]}" if startswith
        dirname = dirname == '/' ? nil : (File.dirname(dirname) + '/')
        prefix = "../#{prefix}"
      end
      
      return filename # give up, don't relativize
    end

    def get_filename(filename)
      @chef_paths.each do |path|
        candidate = File.expand_path(filename, path)
        return candidate if File.exist?(candidate)
      end
      
      # No such file
      @@logger.info "File not found '#{filename}'"
      return nil
    end

    def get_recipes(ruby_role_file)
      unless File.exists?(ruby_role_file)
        @error_reporting.call(Logger::WARN, "Role file not found: #{ruby_recipe.inspect}")
        return []
      end
        
      role_processor = RoleProcessor.new()
      role_processor.instance_eval(File.new(ruby_role_file).read(), ruby_role_file)
      return role_processor.run_list().map { |item| item[/recipe\[(.*)\]/, 1] }
    end
    
    # Given an array of cookbook names, e.g. [ 'jke' ]
    # generate a Hash containing the default values of the parameters
    def get_all_defaults(cookbooks)
      all_defaults = Hash.new { |h, k| h[k] = {} }
      cookbooks.each do |cookbook_name|
        defaults = get_defaults(cookbook_name)
        all_defaults.merge!(defaults) { |key, oldval, newval| newval.merge!(oldval) }
      end
      return all_defaults
    end

    # Given an array of filenames relative to the cookbooks, e.g. [ 'cookbooks/jke/recipes/create_database_mysql.rb' ]
    # generate a Hash containing the default values of the parameters
    def get_param_defaults(ruby_recipes, all_defaults)
      param_defaults = {}
      ruby_recipes.map { |filename| get_filename(filename) }.select { |full_filename| full_filename }.each do |ruby_recipe|
        attr_names = scrape_param_usage(ruby_recipe)
        attr_names.each do |param_name|
          param_cookbook = param_name[/([a-z_]+)\.([a-z_A-Z]+)/, 1]
          
          # Only model parameters from known cookbooks
          if all_defaults.key?(param_cookbook)
            cookbook_defaults = all_defaults[param_cookbook]
            param_name = param_name[/([a-z]+)\.([a-z_A-Z]+)/, 2]
            if cookbook_defaults.key?(param_name)
              param_defaults[param_name] = cookbook_defaults[param_name]
            else
              cookbook_defaults[param_name] = nil
              param_defaults[param_name] = nil
            end
          end
        end
      end
      return param_defaults
    end
    
    def defaults_to_params(param_defaults, parent)
      param_defaults.each do |attr, val|
        property = Attribute.new(attr.symbolize, parent)
        is_pwd = should_encrypt?(property, val)
        property.value =  is_pwd ? EncryptedValue.from_plaintext(val, @keyfile) : val
        property.mutable = true
        property.required = false
        property.name = attr
        property.tags.add(:password) if is_pwd
        
        if val.kind_of?(String)
          property.constrain_value_type(:string)
        elsif val.kind_of?(Fixnum)
          property.constrain_value_type(:numeric)
        end
        
        parent.amd[property.id] = property
      end
    end

    def filter_parameters(hash_of_hashes, params)
      retval = hash_of_hashes.clone
      
      retval.each do |cookbook, parameters|
        parameters.delete_if { |parameter, value| !params.member?("#{cookbook}.#{parameter}") }
      end
      
      retval.delete_if { |cookbook, parameters| parameters.length == 0 }
        
      return retval
    end

  end # class
  
  protected
  
  # mini-DSL to parse a role file
  class RoleProcessor # :nodoc:
    def name(*val)
      return @name if val.empty?
      @name = val[0] 
    end

    def description(*val)
      return @description if val.empty?
      @description = val[0]
    end

    def run_list(*val)
      return @run_list if val.empty?
      @run_list = val
    end
    
    def override_attributes(*val)
      return @override_attributes if val.empty?
      @override_attributes = val[0]
    end
    
  end
  
  # Suppress parse errors in Toaster::DefaultProcessor
  class FailureEater # :nodoc:
    def initialize(name)
      @name = name
    end
    
    def to_s
      return "unknown '#{@name}'"
    end
    
    def method_missing(sym, *args, &block)
      return self
    end
  end
  
  # A String that *doesn't* have quotes when inspected
  class UnquotedString < String # :nodoc:
    def initialize(s)
      super
    end
    
    def inspect
      return to_s
    end
  end
  
end
