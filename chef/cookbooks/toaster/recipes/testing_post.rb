

# Cookbook Name:: toaster
# Recipe:: testing_post
#
# Author:: Waldemar Hummer
# 

# import "postprocessing" recipes. Lookup in the same directory as this file, 
# name pattern "post_<cookbook>_<recipe>.rb"

if node['toaster']['testing_mode']

  index = -1
  run_context.resource_collection.each_with_index do |res,idx|
    if res.name == $last_toaster_resource_name
      index = idx
    end
  end

  class Chef::Recipe
    include Toaster::ChefModules
  end
  resources_before = run_context.resource_collection.all_resources.size
  recipe_dir = File.dirname(File.expand_path(__FILE__))
  recipes_to_include = get_dynamic_recipes(recipe_dir, "post")
  puts "INFO: Starting to include/parse post-processing recipes."
  $status_of_parsing_postprocessing_scripts = "active"
  recipes_to_include.each do |recipe_to_include|
    puts "INFO: Including post-processing recipe '#{recipe_to_include}'"
    include_recipe recipe_to_include
  end
  puts "INFO: Finished including/parsing post-processing recipes."
  $status_of_parsing_postprocessing_scripts = "post"

end
