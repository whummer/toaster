class ScriptsController < ApplicationController

  require "toaster/model/automation"
  require "toaster/model/key_value_pair"
  require "toaster/model/automation_attribute"
  require "toaster/chef/chef_util"

    skip_before_action :verify_authenticity_token

  	def scripts
  		cur_auto_reset()
  	end

  	def edit
  		if request.post? || request.patch?
  			if params[:add_param]
  				auto = cur_auto
          set_auto_values(auto)
  				auto.automation_attributes << Toaster::AutomationAttribute.new(
			  			:key => "", :value => "")
  			elsif params[:del_param]
          set_auto_values(auto)
	  			params[:auto][:attr].each do |index,attr|
	  				if params[:del_param][index]
	  					to_delete = cur_auto.automation_attributes[index.to_i - 1]
	  					cur_auto.automation_attributes.destroy(to_delete) if to_delete
	  					break
	  				end
	  			end
  			elsif params[:add_ignoreprop]
  				auto = cur_auto
          set_auto_values(auto)
  				auto.ignore_properties << Toaster::IgnoreProperty.new(
			  			:key => "", :value => "")
  			elsif params[:del_ignoreprop]
          set_auto_values(auto)
	  			params[:auto][:ignoreprop].each do |index,attr|
	  				if params[:del_ignoreprop][index]
	  					to_delete = cur_auto.ignore_properties[index.to_i - 1]
	  					cur_auto.ignore_properties.destroy(to_delete) if to_delete
	  					break
	  				end
	  			end
  			elsif params[:add_additionalprop]
  				auto = cur_auto
          set_auto_values(auto)
  				auto.additional_properties << Toaster::AdditionalProperty.new(
			  			:key => "", :value => "")
  			elsif params[:del_additionalprop]
          auto = cur_auto
          set_auto_values(auto)
	  			params[:auto][:additionalprop].each do |index,attr|
	  				if params[:del_additionalprop][index]
	  					to_delete = auto.additional_properties[index.to_i - 1]
	  					auto.additional_properties.destroy(to_delete) if to_delete
	  					break
	  				end
	  			end
  			elsif params[:save]
		  		id = params[:auto_id]
		  		auto = nil
		  		if id == "0"
			  		auto = Toaster::Automation.new(
			  			:uuid => Toaster::Util.generate_short_uid)
			  	else
			  		auto = cur_auto
			  	end
	  			set_auto_values(auto)
				auto.save
		  		redirect_to scripts_url()
		  	end
		else
			# TODO
		end
  	end

  	def set_auto_values(auto)
      auto.name = params[:auto][:name]
      auto.language = params[:auto][:language]
      auto.visibility = params[:auto][:visibility]
      auto.user = current_user
      auto.script = params[:auto][:script]
      if params[:auto][:attr]
        params[:auto][:attr].each do |index,attr|
          auto.automation_attributes[index.to_i - 1].key = attr["key"]
          auto.automation_attributes[index.to_i - 1].value = attr["value"]
        end
      end
      if params[:auto][:ignoreprop]
        params[:auto][:ignoreprop].each do |index,prop|
          auto.ignore_properties[index.to_i - 1].key = prop["key"]
        end
      end
      if params[:auto][:additionalprop]
        params[:auto][:additionalprop].each do |index,prop|
          auto.additional_properties[index.to_i - 1].key = prop["key"]
        end
      end
  	end

  	def delete
  		id = params[:auto_id]
  		a = Toaster::Automation.find(id)
  		if a
	  		a.delete
	  	end
	  	redirect_to scripts_url()
  	end

  	def import_chef
  		if params[:submitImport]
        script_file = ChefUtil.get_cookbook_download_link(
          params[:cookbook], params[:cookbook_version])
  			a = Automation.new(
  				:name => params[:auto_name],
  				:cookbook => params[:cookbook],
  				:cookbook_version => params[:cookbook_version],
  				:recipes => params[:recipes],
  				:user => current_user,
  				:script => script_file
  			)
  			# get recipes
  			params[:recipes].split(/[\s,;]+/).each do |rec|
  			  begin
  	  			recipe_info = ChefUtil.parse_resources(
  	  				params[:cookbook], rec, params[:cookbook_version])[params[:cookbook]][rec]
            # get recipe parameters
  		      insp = ChefNodeInspector.new { |level, msg|
              if flash[:notice] 
                flash[:notice].concat(msg)
              else
                flash[:notice] = [msg]
              end 
            }
  		      attr_hash = insp.get_defaults(params[:cookbook], rec)
  	        a.automation_attributes.concat(
  	          KeyValuePair.flat_attributes_from_hash(
  	            attr_hash, AutomationAttribute))

  	  			recipe_info["resources"].each do |line,code|
              action = "__action__"
              resource = "__resource__"
  	  			  if recipe_info["resource_objs"][line]
  		  			   action = recipe_info["resource_objs"][line].action
  	  				   action = action.join(" , ") if action.kind_of?(Array)
  	  				   resource = recipe_info["resource_objs"][line].resource_name
    	        end
  	  				task = Task.new(
  		  				:automation => a,
  		  				:sourceline => line,
  		  				:sourcecode => code,
  		  				:sourcefile => recipe_info["file"],
  		  				:resource => resource,
  		  				:action => action
  		  			)
              # get task parameters
              task.task_parameters = ResourceInspector.get_accessed_parameters(task)
              # save
  		  			task.save
  		  			a.tasks << task
  	  			end
            # save
            a.save
          rescue Object => ex
              msg = "WARN: Unable to import Chef cookbook '#{params[:cookbook]}', " +
                "version '#{params[:cookbook_version]}', recipe '#{rec}': #{ex}"
              flash[:alert] = msg
              puts msg
              puts ex.backtrace.join("\n")
          end
        end
        redirect_to scripts_url()
  		end
  	end

  	def cur_auto_reset()
      session[:auto_cur] = nil
  	end

  	def cur_auto()
  		ScriptsController.cur_auto(session, params)
  	end
  	def self.cur_auto(session, params)
  		if !session[:auto_cur] || (
          session[:auto_cur].id && "#{session[:auto_cur].id}" != params[:auto_id])

  			session[:auto_cur] = nil
  			if params[:auto_id] == "0"
				session[:auto_cur] = Toaster::Automation.new(
					:uuid => Toaster::Util.generate_short_uid)
  			elsif params[:auto_id]
	 	 		session[:auto_cur] = Toaster::Automation.find(params[:auto_id])
	 	 	end
	 	end
 	 	session[:auto_cur]
	end
	def cur_run()
		ExecsController.cur_run(session, params)
	end
	def cur_task()
		ExecsController.cur_task(session, params)
	end

	helper_method :get_automation_for_param, :cur_auto, :cur_auto_or_new, :cur_run, :cur_task
end
