
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/markup/markup_util"
require "toaster/util/util"
require "ohai/application"

include Toaster

module Toaster
  class SystemState

    @@initialized = false
    @@include_default_state_props = false
    @@required_builtin_ohai_plugins = ["languages.rb", "ruby.rb", "kernel.rb", "os.rb"]
    @@original_ohai_plugin_paths = []
    @@ohai_dir = File.join(File.expand_path(File.dirname(__FILE__)), '..', 'ohai')
    @@max_arglist_length = 5000 # maximum number of characters to pass as cmdline parameter to ohai

    def self.get_system_state(state_change_config = {})
      puts "INFO: Taking snapshot of system state..."
      puts "DEBUG: State snapshot configuration: #{state_change_config}" 

      if !@@initialized
        @@original_ohai_plugin_paths.concat(Ohai::Config[:plugin_path])
        @@original_ohai_plugin_paths.each do |path|
          @@required_builtin_ohai_plugins.dup.each do |pl|
            required_file = File.join(path, pl)
            if File.exist?(required_file)
              @@required_builtin_ohai_plugins.delete(pl)
              @@required_builtin_ohai_plugins << required_file
            end
          end
        end
        @@initialized = true
      end

      Ohai::Config[:plugin_path] = []
      if @@include_default_state_props
        Ohai::Config[:plugin_path].concat(@@original_ohai_plugin_paths)
      end

      state_change_config.each do |name,config|
        # register tailor-made Ohai extensions
        path = File.expand_path(File.join(@@ohai_dir, name))
        # puts "Registering ohai extensions within directory #{path}"
        Ohai::Config[:plugin_path].push(path)
      end

      ENV["OHAI_PARAMS"] = state_change_config.to_json().to_s

      # NOTE: We need to be careful here. OHAI_PARAMS is passed as
      # command line argument to ohai, and if this hash becomes
      # too big, we end up with an "Argument list too long" error.
      # If the hash becomes too big, save it to a file and read it 
      # from there afterwards!
      if ENV["OHAI_PARAMS"].size > @@max_arglist_length
        params_file = "/tmp/toaster.ohai_params.tmp"
        Util.write(params_file, ENV["OHAI_PARAMS"], true)
        ENV["OHAI_PARAMS"] = "{\"__read_from_file__\": \"#{params_file}\"}"
      end

      ohai = Ohai::System.new
      @@required_builtin_ohai_plugins.each do |plugin_file|
        begin
          ohai.from_file(plugin_file)
        rescue => ex
          puts "WARN: Unable to include ohai plugin file '#{plugin_file}': #{ex}: #{ex.backtrace.join("\n")}"
          throw ex
        end
      end

      if Ohai::Config[:file]
        ohai.from_file(Ohai::Config[:file])
      else
        ohai.all_plugins
      end
      json = JSON.parse(ohai.to_json)
      filter_unimportant_properties(json)
      #puts "DEBUG: System state json: #{json.inspect}"

      return json
    end

    # Given two states, preprocess the state difference computation
    # by removing those state properties which are usually very large
    # and infeasible to process with the generic approach (structural
    # diff of state property trees).
    #
    # * Returns: an array [s1,s2,diffs] with the (potentially) modified
    #   states ("s1" and "s2") and part of the differences ("diffs")
    #   between the original states.
    def self.preprocess_state_diff(state1, state2)
      diffs = []
      keys1 = state1.keys.dup
      keys2 = state2.keys.dup

      keys1.each do |k|
        file = File.join(@@ohai_dir, k, "_meta.rb")
        if File.exist?(file)
          require file
          s1 = state1[k]
          s2 = state2[k]
          if !s1 || !s2
            next
          end
          tmp_result = nil
          begin
            eval("tmp_result = diff__#{k}(s1, s2)")
            if tmp_result && tmp_result.kind_of?(Array)
              state1.delete(k)
              state2.delete(k)
              diffs.concat(tmp_result)
            end
          rescue => ex
            puts "WARN: Unable to compute diff of state property '#{k}' using code in file #{file}:"
            Util.print_backtrace(ex, 10)
          end
        end
      end

      return [state1, state2, diffs]
    end

    ## Reconstruct the final post-state that results from a
    ## sequence of task executions and their individual
    ## state changes
    def self.reconstruct_state_from_execs_seq(execs_seq)
      state = execs_seq[0].state_before
      #puts "DEBUG: Eliminate map entries from state: #{state}"
      MarkupUtil.eliminate_inserted_map_entries!(state)
      return reconstruct_state_from_change_seq(
        execs_seq.collect{ |ex| ex.state_changes },
        state
      )
    end
    ## Reconstruct the final post-state that results from a
    ## sequence of state changes
    def self.reconstruct_state_from_change_seq(state_change_seq, initial_state={})
      state = initial_state
      state_change_seq.each do |change_set|
        change_set.each do |ch|
          if ch.action == StatePropertyChange::ACTION_DELETE
            #puts "==> delete property #{ch.property}"
            MarkupUtil.delete_value_by_path(state, ch.property)
          elsif ch.action == StatePropertyChange::ACTION_INSERT ||
              ch.action == StatePropertyChange::ACTION_MODIFY
            #puts "==> set property #{ch.property} = #{ch.value}"
            MarkupUtil.set_value_by_path(state, ch.property, ch.value)
          end
        end
      end
      #puts "DEBUG: Reconstructed state from state change sequence: #{state.to_s}"
      return state
    end

    # Compute the difference between two system state snapshots.
    # Returns an array of StatePropertyChange objects.
    def self.get_state_diff(s_before, s_after)
      tmp = preprocess_state_diff(s_before, s_after)
      s_before = tmp[0]
      s_after = tmp[1]
      prop_changes = tmp[2]

      prop_changes.concat(MarkupUtil.hash_diff_as_prop_changes(s_before, s_after))
      return prop_changes
    end

    # Given two states which are "too" big, reduce the size of both states
    # by removing properties that are equal in both states and hence not
    # relevant for the state change computation.
    def self.reduce_state_size(state1, state2)
      state1_copy = state1.dup
      state2_copy = state2.dup

      state1.keys.each do |k|
        file = File.join(@@ohai_dir, k, "_meta.rb")
        if File.exist?(file)
          require file
          s1 = state1[k]
          s2 = state2[k]
          tmp_result = nil
          begin
            eval("tmp_result = reduce__#{k}(s1, s2)")
            if tmp_result && tmp_result.kind_of?(Array)
              state1_copy[k] = tmp_result[0]
              state2_copy[k] = tmp_result[1]
            end
          rescue => ex
            puts "WARN: Unable to compute reduced hash of state property '#{k}' using code in file #{file}:"
            Util.print_backtrace(ex, 10)
          end
        end
      end
      return [state1_copy, state2_copy]
    end

    def self.get_statechange_config_from_state(state)
      cfg = {}
      if state["files"]
        cfg["files"] = {"paths" => []}
        state["files"].each do |path,info|
          cfg["files"]["paths"] << path
        end
      end
      return cfg
    end

    def self.read_ignore_properties()
      result = Set.new
      Dir["#{@@ohai_dir}/*"].each do |dir|
        file = File.join(dir, "_meta.rb")
        if File.exist?(file)
          require file
          tmp_result = nil
          name = dir.sub(/.*\/([a-z0-9A-Z_\-]+)\/*/, '\1')
          begin
            eval("tmp_result = ignore_properties__#{name}()")
            tmp_result = [tmp_result] if !tmp_result.kind_of?(Array)
            tmp_result.each do |r|
              result << r
            end
          rescue => ex
            puts "WARN: Unable to get ignore properties using code in file #{file}:"
            Util.print_backtrace(ex, 10)
          end
        end
      end
      return result.to_a()
    end

    def self.remove_ignore_props!(props_hash, ignore_prop_names=nil, key_path=[], print_info=false)
      if !ignore_prop_names
        ignore_prop_names = read_ignore_properties()
      end
      #puts "TRACE: ignore_prop_names #{ignore_prop_names}"
      ignore_prop_names.each do |key|
        if props_hash.kind_of?(Array)
          props_hash.dup.each do |k|

            # check if we have an array of StatePropertyChange
            if k.kind_of?(StatePropertyChange)
              if k.property.eql?(key) ||
              Util.starts_with?(k.property, "#{key}.") ||
              k.property.match(key)
                props_hash.delete(k)
              end

            else
              # this is not a StatePropertyChange, but an
              # array of values or hashes --> to be implemented
              puts "WARN: SystemState.remove_ignore_props(..) not implemented for non-StatePropertyChange arrays!"
            end
          end

        else
          # assume this is an actual state properties hash
          props_hash.keys.dup.each do |k|
            new_path = key_path.dup
            new_path << k
            long_key = "'#{new_path.join("'.'")}'"
            #puts "TRACE: long key #{long_key}"
            if k == "#{key}" || Util.starts_with?(k, "#{key}.") || k.match(key) ||
            long_key == "#{key}" || Util.starts_with?(long_key, "#{key}.") || long_key.match(key)
              deleted = props_hash.delete(k)
            elsif props_hash[k].kind_of?(Hash)
              # --> recursion!
              remove_ignore_props!(props_hash[k], ignore_prop_names, new_path)
            end
          end
        end
      end
    end

    def self.get_flat_attributes(current=nil, name_so_far="", list_so_far={})
      if current.nil?
        name_so_far = name_so_far[1..-1] if name_so_far[0] == "."
        list_so_far[name_so_far] = nil
        return list_so_far
      end
      if !current.kind_of?(Hash)
        name_so_far = name_so_far[1..-1] if name_so_far[0] == "."
        list_so_far[name_so_far] = current
        return
      end
      current.each do |name,value|
        name = "#{name_so_far}.'#{name}'"
        get_flat_attributes(value, name, list_so_far)
      end
      return list_so_far
    end

    private

    def self.filter_unimportant_properties(json)
      if @@include_default_state_props
        remove_properties(json, ["network", "interfaces"])
        remove_properties(json, ["counters", "network", "interfaces"])
        remove_properties(json, ["etc", "passwd"])
        remove_properties(json, ["etc", "group"])
        remove_properties(json, ["cpu", "json--map--entry", "value", "flags"])
        remove_properties(json, ["filesystem"])
        remove_properties(json, ["uptime_seconds"])
        remove_properties(json, ["uptime"])
        remove_properties(json, ["idletime_seconds"])
        remove_properties(json, ["ohai_time"])
        remove_properties(json, ["idletime"])
        remove_properties(json, ["kernel", "version"])
        remove_properties(json, ["os_version"])
        remove_properties(json, ["os"])
        #remove_properties(json, ["memory", "anon-pages"])
        #remove_properties(json, ["memory", "dirty"])
        remove_properties(json, ["dmi"]) # for now, ignore the whole dmi section
        remove_properties(json, ["memory"]) # for now, ignore the whole memory section
        remove_properties(json, ["cpu"]) # for now, ignore the whole cpu section
        remove_properties(json, ["block_device"]) # for now, ignore the whole block_device section
        #remove_properties(json, ["block_device",/ram.*/])
        remove_properties(json, ["keys"])
        remove_properties(json, ["chef_packages"])
        remove_properties(json, ["kernel","modules",/.*/,"size"])
        remove_properties(json, ["kernel","modules",/.*/,"refcount"])
      end

      remove_properties(json, ["languages"])

      remove_properties(json, ["nginx"]) # this is added automatically by the nginx Chef recipe

      if json["kernel"] && json["kernel"]["modules"]
        mod_names = ""
        json["kernel"]["modules"].each do |key,value|
          mod_names += key + " "
        end
        json["kernel"]["modules"] = mod_names.strip
      end
    end

    def self.remove_properties(json, props)
      MarkupUtil.remove_properties(json, props)
    end

  end
end

#Toaster::MarkupUtil.get_keys_path_from_expr("files['/etc/default/netkernel']")
#Toaster::MarkupUtil.get_keys_path_from_expr("foo.bar['/etc/default/netkernel']")
#Toaster::MarkupUtil.get_keys_path_from_expr("foo.bar.'abc'")


#hash3 = {"zlib1g:amd64"=>"1:1.2.7.dfsg-13", "zlib1g-dev:amd64"=>"1:1.2.7.dfsg-13"}
#hash4 = {"zlib1g:amd64"=>"1:1.2.7.dfsg-13", "zlib1g-dev:amd64"=>"1:1.2.7.dfsg-131"}
#hash = {"files"=>{"/etc/chef/ohai_plugins/nginx.rb" => {"ctime" => 1}},
#  "packages" => {"apt-utils"=>"0.9.7.5ubuntu5", "autotools-dev"=>"20120608.1", "cpp-4.6"=>"4.6.3-10ubuntu1", "cpp-4.7"=>"4.7.2-2ubuntu1"}
#}
#puts Toaster::MarkupUtil.hash_diff_as_prop_changes(hash3, hash4)
#puts HashDiff.diff(hash3, hash4)
#puts hash
#puts Toaster::MarkupUtil.get_value_by_path(hash, "'files'.'/etc/chef/ohai_plugins/nginx.rb'")
#puts hash
#Toaster::MarkupUtil.rectify_keys(hash)
#puts hash
#Toaster::SystemState.remove_ignore_props!(hash)
#puts hash
