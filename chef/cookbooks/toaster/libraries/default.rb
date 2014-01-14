

# commonly used library functionality 

module Toaster

  module ChefModules
    def get_dynamic_recipes(base_dir, type="pre") # type is "pre" or "post"
      result = []
      pattern = "#{base_dir}/*.rb"
      Dir[pattern].each do |recipe_file|
        file_name = recipe_file.gsub(/.*\/([^\/]+)\.rb$/, '\1')
        if file_name.match(/^#{type}__/)
          cookbook_name = nil
          if file_name.match(/^#{type}__(.*)__(.*)/)
            cookbook_name = file_name.sub(/^#{type}__(.*)__(.*)/, '\1')
          elsif file_name.match(/^#{type}__(.*)$/)
            cookbook_name = file_name.sub(/^#{type}__(.*)$/, '\1')
          end
          recipe_name = nil
          if file_name.match(/^#{type}__(.*)__(.*)/)
            recipe_name = file_name.sub(/^#{type}__(.*)__(.*)/, '\2')
          end
          node.run_list.each do |run_item|
            # convert Chef::RunList::RunListItem to string
            run_item = "#{run_item}"
            run_item = "recipe[#{run_item}]" if !run_item.include?("[")
            # check if runlist item is a recipe
            if run_item.match(/^recipe\[/)
              run_item = run_item.sub(/^recipe\[(.*)\]/, '\1')
              run_item = "#{run_item}::default" if !run_item.include?("::")
              parts = run_item.split("::")
              run_cookbook = parts[0]
              run_recipe = parts[1]
              #puts "#{cookbook_name} - #{recipe_name} - #{run_cookbook} - #{run_recipe}"
              if (cookbook_name == run_cookbook) && 
                  ((!recipe_name) || (recipe_name == run_recipe))
                result << "toaster::#{file_name}"
              end
            end
          end
        end
      end
      return result
    end
  end

  # Simple PROXY class implementation
  class Proxy
    attr_accessor :target
    def initialize(target)
      @target = target
    end
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$|^target)/ }
    protected
    def method_missing(name, *args, &block)
      @target.send(name, *args, &block)
    end
  end

end
