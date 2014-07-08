

# Cookbook Name:: toaster
# Recipe:: testing
#
# Author:: Waldemar Hummer

puts "INFO: Initializing toaster::testing environment"

# some (actually quite many) recipes rely on recipe openssl but apparently fail to load it by default
include_recipe "openssl"
class Chef::Recipe
  begin
    include ::Opscode::OpenSSL::Password
  rescue Object => ex
    # This does not work under new Ruby 2.0.0 which 
    # apparently ships with a new/updated version of openssl.
  end
end
# uncomment this to test whether the openssl dependency has been successfully installed
#foo = secure_password

# make sure Chef knows we're running in solo mode
Chef::Config[:solo] = true

# make sure IBM Java does not get (re-)installed if recipe 
# "java::default" gets included by any of the Opscode recipes
node.set[:java][:jvm] = '__ignore__' # attribte should _not_ have value "IBM"
# set default JAVA_HOME
node.set["java"]["java_home"] = "/opt/ibm/java-x86_64-60/jre" if !node["java"]["java_home"]

# create Chef data_bags directory, if it does not yet exist (fixes an 
# issue where Chef was complaining that /var/chef/data_bags does not exist)
require 'fileutils'
databags_dir = "/var/chef/data_bags"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)

package "gcc-c++" do
  action :install
  not_if "which g++"
end

# dependencies required for gems
if platform_family?("debian")
  apt_package "libxml2-dev"
  apt_package "libxslt-dev"
  apt_package "nmap" do
    not_if "which nmap"
  end
elsif platform_family?("fedora") || platform_family?("linux")
  yum_package "libxml2-devel" 
  yum_package "libxslt-devel"
  yum_package "nmap" do
    not_if "which nmap"
  end

end


$installed_gems = `gem list --local`.strip

all_gems_installed = true

[
  "ohai",         # used as a framework to capture system state
  "activesupport",
  "bson",         # JSON like datastructures
  "bson_ext",     # native JSON extension
  "sexp_processor", # required by gem 'ruby_parser'
  "ruby_parser",
  "rails",        # provides some utility methods
  "rspec",        # unit tests
  "open4",        # allows to read stdout from a forked process, line by line
  "jsonpath",     # select sub-parts of a state property JSON document
  "hashdiff",     # compute state property changes
  "tidy",         # tidy XML support. Note: gem "tidy" is not compatible with some Ruby versions
  "tidy-ext",     # XML tidy parsing
  "json",         # JSON support
].uniq.each do |pkg|

  if node['toaster']['testing_mode'] && !$installed_gems.match(pkg)
    all_gems_installed = false
    r = gem_package pkg do
      action :install
    end
  end

end


bash "install_toaster_gem" do
  require 'toaster/util/config'
  code <<-EOH
    gem install --no-ri --no-rdoc cloud-toaster
  EOH
  not_if "which toaster"
end

# start instrumentation of Chef environment

$status_of_parsing_postprocessing_scripts = "off"
$postprocessing_scripts = []
$postprocessing_scripts_by_name = {}

# Add code directories to Ruby LOAD_PATH.
code_dir = File.join(__FILE__, "..","..","..","..", "lib")
$:.unshift(code_dir)
if node['toaster']['additional_load_paths'].kind_of?(Array)
  node['toaster']['additional_load_paths'].each do |path|
    if File.exist?(path)
      puts "INFO: Adding folder to $LOAD_PATH: #{path}"
      $:.unshift(path)
    end
  end
end

if !File.directory?("#{node['toaster']['tmp_dir']}")
  `mkdir "#{node['toaster']['tmp_dir']}"`
end

if !$installed_gems.match("aquarium")
  `gem install aquarium`
  begin
    # the following two commands are used to load gems that were just installed 
    Gem.clear_paths
    Gem.refresh
  rescue => ex
    puts "Unable to refresh Gem package list: #{ex}"
  end
end


$last_toaster_resource_name = "toaster_init_chef_listener"
ruby_block $last_toaster_resource_name do
  block do

    require 'rubygems'
    begin
      # the following two commands are used to load gems that were actually installed 
      # within this Chef run and are hence not yet available in this running instance.
      Gem.clear_paths
      Gem.refresh
    rescue => ex
      puts "Unable to refresh Gem package list: #{ex}"
    end
    require 'aquarium'
    require 'toaster/test_manager'
    require 'toaster/chef/chef_listener'

    begin
      db_type = node['toaster']['db_type']
      mgr = Toaster::TestManager.new(
        {
          "db_type" => db_type,
          db_type => node['toaster'][db_type],
          "user_id" => node['user_id'],
          "automation_uuid" => node['automation_uuid'],
          "cookbook_paths" => node['toaster']['cookbook_paths'],
          "skip_tasks" => node['toaster']['skip_tasks'],
          "repeat_tasks" => node['toaster']['repeat_tasks'],
          "task_execution_timeout" => node['toaster']['task_execution_timeout'],
          "transfer_state_config" => node['toaster']['transfer_state_config'],
          "task_exec_timeout_repeated" => node['toaster']['task_exec_timeout_repeated'],
          "rest_timeout" => node['toaster']['rest_timeout'] ? node['toaster']['rest_timeout'] : 5*60
        }
      )
      Toaster::ChefListener.add_listener(mgr)
    rescue => ex
      puts "ERROR: Unable to initialize ToASTER: #{ex} - #{ex.backtrace.join("\n")}"
    end
    $chef_instrumented = true
  end
  not_if do (node['toaster']['testing_mode'] != true) || ($chef_instrumented) end
end

require "aquarium"
Aquarium::Aspects::Aspect.new :around, :calls_to => /insert/,
:for_types => [Chef::ResourceCollection],
:method_options => :exclude_ancestor_methods do |jp, obj, *args|
  begin
    if jp.method_name.to_s == "insert"
      name = args[0].to_s
      if $status_of_parsing_postprocessing_scripts == "active"
        contained = false
        run_context.resource_collection.all_resources.each do |res|
          if res.to_s == name
            contained = true
            break
          end
        end
        if contained
          puts "INFO: Injecting/replacing post-processing resource '#{name}'."
          old_resource = run_context.resource_collection.find(name).target
          new_resource = args[0]
          new_resource.cookbook_name = old_resource.cookbook_name
          new_resource.recipe_name = old_resource.recipe_name
          new_resource.source_line = old_resource.source_line
          run_context.resource_collection.find(name).target = new_resource
        else
          puts "INFO: Appending new post-processing resource '#{name}'."
          run_context.resource_collection << Toaster::Proxy.new(args[0])
        end

      else $status_of_parsing_postprocessing_scripts == "off"
        #puts "DEBUG: Wrapping resource #{jp.context.parameters[0]} with proxy object."
        jp.context.parameters[0] = Toaster::Proxy.new(jp.context.parameters[0])
        jp.proceed
      end
    else
      begin
        jp.proceed
      rescue Object => exc
        puts "Exception intercepting Chef::ResourceCollection.#{jp.method_name}: #{exc.class} - #{exc} - #{exc.backtrace.join("\n")}"
        puts "Existing resources:"
        run_context.resource_collection.all_resources.each do |res|
          puts res
        end
        puts "--------"
      end
    end
  end
end

class Chef::Recipe
  include Toaster::ChefModules
end
# import "preprocessing" recipes. Lookup in the same directory as this file, 
# name pattern "pre_<cookbook>_<recipe>.rb"
if node['toaster']['testing_mode']
  recipe_dir = File.dirname(File.expand_path(__FILE__))
  recipes_to_include = get_dynamic_recipes(recipe_dir, "pre")
  recipes_to_include.each do |recipe_to_include|
    puts "INFO: Including preparation recipe '#{recipe_to_include}'"
    begin
      include_recipe recipe_to_include
    rescue Object => exc
      puts "WARN: Exception in include_recipe: #{recipe_to_include}: #{exc.class} - #{exc} - #{exc.backtrace.join("\n")}"
    end
  end
end

