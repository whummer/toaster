

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'chef/log'
require 'chef/run_context'
require 'chef/client'
require 'toaster/markup/markup_util'

# the requires below are required, otherwise:
# uninitialized constant RubyLexer::RubyParserStuff
# [...]/ruby_parser-3.1.1/lib/ruby_lexer.rb:241:in
require 'ruby_lexer'
require 'ruby_parser_extras'
class RubyLexer
  begin
    RubyParserStuff = Kernel.const_get("RubyParserStuff")
  rescue Object => exc
    begin
      RubyParserStuff = ::RubyParserStuff
    rescue Object => exc1
      puts "WARN: Unable to load the module 'RubyParserStuff' into class RubyLexer"
    end
  end
end

require 'ruby_parser'
require 'chef/application/solo'
require 'toaster/markup/markup_util'
require 'toaster/util/util'
require 'toaster/chef/resource_inspector'
require 'rexml/document'

module Toaster
  class ChefUtil
    @@chef_classes = {}
    @@create_backups = false

    #OPSCODE_API_URL = "http://cookbooks.opscode.com/api/v1/"
    #OPSCODE_API_URL = "https://supermarket.getchef.com/api/v1/"
    OPSCODE_API_URL = "https://supermarket.chef.io/api/v1/"
    OPSCODE_SEARCH_URL = "http://community.opscode.com/search"

    @@DEFAULT_CHEF_DIR = "/tmp/toaster_cookbooks/"
    @@DEFAULT_COOKBOOKS_DIR = "#{@@DEFAULT_CHEF_DIR}/cookbooks/"
    @@DEFAULT_OPSCODE_TMP_DIR = "/tmp/opscode_cookbooks/" # TODO merge with above?

    def self.DEFAULT_CHEF_DIR
      @@DEFAULT_CHEF_DIR
    end
    def self.DEFAULT_COOKBOOKS_DIR
      @@DEFAULT_COOKBOOKS_DIR
    end
    def self.DEFAULT_OPSCODE_TMP_DIR
      @@DEFAULT_OPSCODE_TMP_DIR
    end

    def self.guess_cookbook_from_runlist(runlist)
      guess_cookbook_or_recipe_from_runlist(runlist, "cookbook")
    end
    def self.guess_recipe_from_runlist(runlist)
      guess_cookbook_or_recipe_from_runlist(runlist, "recipe")
    end

    def self.guess_cookbook_or_recipe_from_runlist(runlist, type)
      candidates = []
      runlist.each do |i|
        if !i.match(/toaster::testing/)
          if i.include?("recipe[")
            if type == "cookbook"
              candidates << i.gsub(/recipe\[(.*::)*([^\]]+)\]/, '\1').gsub(/::/, '')
            elsif type == "recipe"
              candidates << i.gsub(/recipe\[(.*::)*([^\]]+)\]/, '\2')
            end
          end
        end
      end
      return "default" if candidates.empty?
      puts "WARN: Multiple #{type}s found in runlist #{runlist}: #{candidates}" if candidates.size > 1
      return candidates[0]
    end

    def self.extract_node_name(name) 
      short_name = name
      short_name = short_name.gsub(/.*node\[(.+)\]/, '\1') if short_name.include?("node[")
      return short_name
    end

    def self.get_chef_log_level()
      return Chef::Log.level
    end
    def self.set_chef_log_level(level)
      Chef::Log.level = level
    end

    def self.get_absolute_file_path(cookbook_paths, relative_file_path)
      cookbook_paths.each do |path|
        f_path = File.join(path, relative_file_path)
        return f_path if File.exist?(f_path)
      end
      return nil
    end

    def self.get_attribute_file(recipe_file)
      attr_dir = File.join(File.dirname(recipe_file), "..", "attributes")
      recipe_name = recipe_file.gsub(/.*\/([^\/]+)\.rb$/, '\1')
      dflt_attr_file = File.join(attr_dir, "#{recipe_name}.rb")
      return dflt_attr_file if File.exist?(dflt_attr_file)
      return nil if !File.exist?(attr_dir)
      content = Dir.entries(attr_dir)
      content.each do |f|
        if f.to_s.match(/.*\.rb$/)
          return File.join(attr_dir, f)
        end
      end
      return nil
    end

    def self.wrap_node_name(node_name)
      node_name = "node[#{node_name}]" if !node_name.include?("node[")
    end

    def self.get_reduced_run_list(run_list)
      reduced_run_list = run_list.select{ |i| 
        !"#{i}".match(/toaster::testing/) && 
        !"#{i}".match(/chef-solo-search::default/)
      }
      return reduced_run_list
    end

    def self.prepare_run_list(chef_node, run_list_hash_OR_chef_node_file)
      run_list = []

      #puts "run_list_hash_OR_chef_node_file - #{run_list_hash_OR_chef_node_file} - #{run_list_hash_OR_chef_node_file.class}"
      if !run_list_hash_OR_chef_node_file || 
          (run_list_hash_OR_chef_node_file.kind_of?(Array) && run_list_hash_OR_chef_node_file.empty?)
        run_list = ["recipe[#{chef_node}::default]"]
      elsif run_list_hash_OR_chef_node_file.kind_of?(Array)
        run_list = run_list_hash_OR_chef_node_file
      else
        node_file = run_list_hash_OR_chef_node_file
        if File.exist?(node_file)
          run_list = JSON.parse(File.read(node_file))["run_list"]
        else
          run_list = [node_file]
        end
      end
      run_list = [run_list] if !run_list.kind_of?(Array)
      # append toaster::testing recipe to the beginning of the 
      # run list to enable the testing mechanism!
      if run_list[0] != "recipe[toaster::testing]"
        # due to recent changes in Chef 11, we also need to add
        # chef-solo-search::default into the run_list, in order
        # to load the libraries defined there (we depend on
        # a library function that overwrites the search(...) 
        # function). More info concerning this Chef 11 change:
        # http://docs.opscode.com/breaking_changes_chef_11.html#non-recipe-file-evaluation-includes-dependencies
        run_list.unshift("recipe[chef-solo-search::default]")
        # ... and now add toaster::testing to the beginning
        run_list.unshift("recipe[toaster::testing]")
      end
      # ... and append toaster::testing_post to the end of the run list
      if run_list[-1] != "recipe[toaster::testing_post]"
        run_list << "recipe[toaster::testing_post]"
      end
      return run_list
    end

    def self.create_chef_config(solo_file)
      root_dir = Util.project_root_dir()
      puts "DEBUG: Writing Chef configuration (cookbook_path) to '#{solo_file}'"
      Util.write(solo_file, (<<-EOF
      cookbook_path [
        "#{File.expand_path(File.join(Dir.pwd, "cookbooks"))}",
        "#{@@DEFAULT_COOKBOOKS_DIR}",
        "#{File.join(root_dir, "chef", "cookbooks")}"
      ]
    EOF
    ), true)
    end

    def self.run_chef(chef_solo_file, node_file, print_output=true)
      cmd = "chef-solo -c #{chef_solo_file} -j #{node_file} 2>&1 | grep -v 'FATAL: No cookbook found in'"
      if print_output
        system(cmd)
      else
        `#{cmd}`
      end
    end

    def self.read_sourcecode(start_source_line)
      # start_source_line looks like the following example:
      # /home/user/dir/file.rb:82:in `from_file'
      file = get_sourcefile(start_source_line)
      line = get_sourceline(start_source_line)
      read_sourcecode_from_line(file, line)
    end

    def self.read_sourcecode_from_line(file, line)
      lines = File.readlines(file)
      parsed_source = nil
      last_line = -1
      # read the source code file line by line and attempt to parse.
      for endline in line..lines.size
        code = lines[(line-1)..(endline-1)].join
        previous_stderr = $stderr
        $stderr.sync = true
        $stderr = StringIO.open('','w')
        begin
          
          parser = RubyParser.new
          parser.process(code.dup)
          parsed_source = code
          last_line = endline
          break
        rescue Exception => ex
          ## swallow
        ensure
          $stderr = previous_stderr
        end
      end
      #puts "source code, lines #{line} to #{last_line} of file #{file}:\n #{parsed_source}"
      return parsed_source
    end

    def self.get_sourcefile(start_source_line)
      l = start_source_line.split(":")
      return l[0]
    end

    def self.get_sourceline(start_source_line)
      l = start_source_line.split(":")
      return l[1].to_i
    end

    def self.get_cookbook_download_link(name, version="latest")
      url = "#{OPSCODE_API_URL}cookbooks/#{name}/versions/#{version}"
      puts "DEBUG: Getting Chef cookbook metadata from URL: '#{url}'"
      json = `curl #{url} 2> /dev/null`
      begin
        json = MarkupUtil.parse_json(json)
      rescue => ex
        raise "Unable to parse string as JSON (received from URL #{url}): #{json}"
      end
      return json["file"]
    end

    def self.download_cookbook_version(name, version="latest", 
          target_dir=@@DEFAULT_COOKBOOKS_DIR, quiet=false, num_attempts=2)
      link = get_cookbook_download_link(name, version)
      download_cookbook_url(link, target_dir, quiet, num_attempts)
    end

    # TODO remove?
#    def self.download_cookbook_version1(name, version="latest", 
#          target_dir=@@DEFAULT_COOKBOOKS_DIR, quiet=false, num_attempts=2)
#
#      link = get_cookbook_download_link(name, version)
#
#      `mkdir -p '#{target_dir}'` if !File.exist?(target_dir)
#      tgz_file = File.join(target_dir, "#{name}.tgz")
#      tar_file = File.join(target_dir, "#{name}.tar")
#      File.delete(tar_file) if File.exist?(tar_file)
#      cookbook_dir = File.join(target_dir, name)
#      if @@create_backups
#        if File.exist?(cookbook_dir) && !File.exist?("#{cookbook_dir}.bak")
#          `mv #{cookbook_dir} #{cookbook_dir}.bak`
#        end
#      end
#      while num_attempts > 0
#        `rm -rf #{cookbook_dir}`
#        if !quiet
#          puts "DEBUG: Downloading '#{link}' to #{target_dir}"
#        end
#        error = false
#        `wget #{link} -O #{tgz_file} > /dev/null 2>&1`
#        error ||= $?.exitstatus != 0
#        out = `cd #{target_dir} && tar zxf #{name}.tgz`
#        # tar reports status code 2 in case of error...
#        if $?.exitstatus > 1
#          # sometimes, the files are in tar format, 
#          # not in tgz format - let's give it a try!
#          puts "DEBUG: 'cd #{target_dir} && tar zxf #{name}.tgz' returned exit code #{$?.exitstatus}, trying to extract as tar file..."
#          full_file = "#{target_dir}/#{name}.tgz"
#          puts "DEBUG: File #{full_file} exists: #{File.exist?(full_file)}}"
#          out += `cd #{target_dir} && cp #{name}.tgz #{name}.tar`
#          out += `cd #{target_dir} && tar xf #{name}.tar`
#        end
#        error ||= $?.exitstatus > 1
#        break if !error
#        puts "WARN: Could not download/extract #{link} to #{target_dir} . Remaining attempts: #{num_attempts}"
#        num_attempts -= 1
#        sleep 2
#      end
#
#      return out   
#    end

    def self.download_cookbook_url(link, target_dir=@@DEFAULT_COOKBOOKS_DIR, 
        quiet=false, num_attempts=2)
      out = ""
      if !File.exist?(target_dir)
        FileUtils.mkpath(target_dir)
      end
      cookbooks_before = Dir.entries(target_dir)
      Toaster::Util.mktmpfile() { |tgz_file|
        while num_attempts > 0
          if !quiet
            puts "DEBUG: Downloading '#{link}' to #{target_dir}"
          end
          error = false
          `wget #{link} -O #{tgz_file} > /dev/null 2>&1`
          error ||= $?.exitstatus != 0
          cmd = "cd #{target_dir} && tar -z -x -f #{tgz_file}"
          out = `#{cmd}`
          # tar reports status code 2 in case of error...
          if $?.exitstatus > 1
            # sometimes, the files are in tar format, 
            # not in tgz format - let's give it a try!
            puts "DEBUG: '#{cmd}' returned exit code #{$?.exitstatus}, trying to extract as tar file..."
            #full_file = "#{target_dir}/#{name}.tgz"
            #puts "DEBUG: File #{full_file} exists: #{File.exist?(full_file)}}"
            #out += `cd #{target_dir} && cp #{name}.tgz #{name}.tar`
            out += `cd #{target_dir} && tar -x -f #{tgz_file}`
          end
          error ||= $?.exitstatus > 1
          break if !error
          puts "WARN: Could not download/extract #{link} to #{target_dir} . Remaining attempts: #{num_attempts}"
          num_attempts -= 1
          sleep 2
        end
      }

      cookbooks_after = Dir.entries(target_dir)
      new_cb = cookbooks_after - cookbooks_before
      puts "INFO: Downloaded and installed new cookbooks: #{new_cb}" if !new_cb.empty?

      # download dependencies
      new_cb.each do |cb|
        download_dependencies(cb, nil, target_dir, true)
      end

      return new_cb
    end

    def self.fix_encodings(target_dir=@@DEFAULT_COOKBOOKS_DIR)
      # add 'encoding' headers to avoid "invalid multibyte char" errors
      out1 = `cd  #{target_dir} && magic_encoding`
      puts "DEBUG: magic_encoding: #{out1}"
    end

    def self.download_cookbook_url_in_lxc(lxc, link, target_dir=@@DEFAULT_COOKBOOKS_DIR)
      cookbook_dir = "#{lxc['rootdir']}/#{target_dir}"
      download_cookbook_url(link, cookbook_dir)
    end

    def self.download_cookbook_version_in_lxc(lxc, name, version="latest", target_dir=@@DEFAULT_COOKBOOKS_DIR)
      cookbook_dir = "#{lxc['rootdir']}/#{target_dir}"
      download_cookbook_version(name, version, cookbook_dir)
    end

    def self.download_latest_cookbook(name, target_dir=@@DEFAULT_COOKBOOKS_DIR)
      download_cookbook_version(name, "latest", target_dir)
    end

    def self.download_latest_cookbook_in_lxc(lxc, name, target_dir=@@DEFAULT_COOKBOOKS_DIR)
      download_cookbook_version_in_lxc(lxc, name, "latest", target_dir)
    end

    def self.lxc_cookbook_dir(lxc, relative_dir=@@DEFAULT_COOKBOOKS_DIR)
      return "#{lxc['rootdir']}/#{relative_dir}"
    end

    def self.fix_known_bugs_in_recipes(cookbook_dir=@@DEFAULT_COOKBOOKS_DIR, phase="after")

      if phase == "before"
        puts "DEBUG: Cleaning up cookbooks directory before downloading.."

        # it seems that there is an issue with hadoop_cluster/attributes/default.rb
        if File.exist?("#{cookbook_dir}/hadoop_cluster")
          puts "DEBUG: Removing cookbook directory #{cookbook_dir}/hadoop_cluster (bug in attributes)"
          `rm -rf "#{cookbook_dir}/hadoop_cluster"`
        end

      elsif phase == "after"
        puts "DEBUG: Fixing some known bugs in existing recipes.."

        # get rid of the col  on at the end of this line:
        # "if (not new_resource.dependency.empty?):"
        if File.exist?("#{cookbook_dir}/node/providers/nodejs.rb")
          `sed -i "s/empty?):/empty?)/" #{cookbook_dir}/node/providers/nodejs.rb`
        end

        # recipe php::php5 doesn't exist anymore (bug in recipe cakephp::default)
        if File.exist?("#{cookbook_dir}/cakephp/recipes/default.rb")
          `sed -i 's/include_recipe .*php5.*$/include_recipe %w{php::default php::module_mysql}/' #{cookbook_dir}/cakephp/recipes/default.rb`
        end

        # cookbook "recognizer" uses old Chef syntax, incompatible with new Chef versions
        if File.exist?("#{cookbook_dir}/recognizer/libraries/json_file.rb")
          `sed -i 's/attribute :content, :kind_of => Hash/state_attrs :content/' #{cookbook_dir}/recognizer/libraries/json_file.rb`
        end

        # cookbook "netkernel" uses invalid syntax
        file = "#{cookbook_dir}/netkernel/recipes/default.rb"
        if File.exist?(file)
          `sed -i 's/source defaults.erb/source "defaults.erb"/' #{file}`
        end

        # cookbook "recognizer" uses invalid syntax
        file = "#{cookbook_dir}/recognizer/recipes/default.rb"
        if File.exist?(file)
          `sed -i 's/content recognizer_config/content recognizer_config.to_s/' #{file}`
        end

        # cookbook "bacula" uses invalid syntax
        file = "#{cookbook_dir}/bacula/recipes/bat.rb"
        if File.exist?(file)
          `sed -i 's/=> n\\[/=> node[/' #{file}`
        end

        # cookbook "openvpn" uses invalid syntax
        file = "#{cookbook_dir}/openvpn/recipes/default.rb"
        if File.exist?(file)
          `sed -i 's/routes.flatten\!/routes.dup.flatten\!/' #{file}`
        end

        # cookbook "bacula" uses invalid syntax
        file = "#{cookbook_dir}/sanitize/recipes/default.rb"
        if File.exist?(file)
          `sed -i 's/node\\[\\'build_essential\\'][\\'compiletime\\'] = /node.set\\[\\'build_essential\\'][\\'compiletime\\'] = /' #{file}`
        end

        # cookbook "riak" uses invalid attribute syntax
        files = ["#{cookbook_dir}/riak/attributes/kv.rb", 
          "#{cookbook_dir}/riak/attributes/sasl.rb", 
          "#{cookbook_dir}/riak/attributes/bitcask.rb"]
        files.each do |file|
          if File.exist?(file)
            `sed -i 's/node.riak.kv.storage_backend = /set["riak"]["kv"]["storage_backend"] = /' #{file}`
            `sed -i 's/node.riak.sasl.errlog_type = /set["riak"]["sasl"]["errlog_type"] = /' #{file}`
            `sed -i 's/node.riak.bitcask.sync_strategy = /set["riak"]["bitcask"]["sync_strategy"] = /' #{file}`
          end
        end
        
        # openldap/attributes/default.rb attempts to access node['domain'] which is nil
        file = "#{cookbook_dir}/openldap/attributes/default.rb"
        if File.exist?(file)
          if !File.read(file).match("file_patched_for_toaster_testing")
            `sed -i "1idefault['domain']='' if !node['domain']" "#{file}"`
            `sed -i "2i#file_patched_for_toaster_testing" "#{file}"`
          end
        end

        # fix new syntax of resource notifications
        files = ["apache2/definitions/apache_site.rb", "tomcat6/recipes/default.rb"]
        files.each do |file|
          file = "#{cookbook_dir}/#{file}"
          if File.exist?(file)
            `sed -i 's/resources(:\\([a-z_]*\\) => "\\([^"]*\\)")/"\\1[\\2]"/g' "#{file}"`
          end
        end

        # new attribute access in Chef 11
        file = "#{cookbook_dir}/kafka/recipes/default.rb"
        if File.exist?(file)
          `sed -i "s/node\\\\[:kafka\\\\]\\\\[:broker_host_name\\\\] =/node.set[:kafka][:broker_host_name] =/" "#{file}"`
          `sed -i "s/node\\\\[:kafka\\\\]\\\\[:broker_id\\\\] =/node.set[:kafka][:broker_id] =/" "#{file}"`
        end
        file = "#{cookbook_dir}/network_interfaces/recipes/default.rb"
        if File.exist?(file)
          `sed -i 's/node\\["network_interfaces"\\]\\["order"\\]=/node.set["network_interfaces"]["order"]=/' "#{file}"`
        end

        # add cookbook dependencies
        dependencies = {  "vmware" => ["apt"],
                          "maven" => ["ark"],
                          "sonar" => ["ark", "maven"],
                          "eaccelerator" => ["apache2"],
                          "netkernel" => ["apache"],
                          "chef-client-cron" => ["chef-client"]
                       }
        dependencies.each do |cb,deps|
          deps.each do |dep|
            # add dependency to cookbook metadata
            file1 = "#{cookbook_dir}/#{dep}/"
            file2 = "#{cookbook_dir}/#{cb}/metadata.rb"
            if File.exist?(file1) && File.exist?(file2)
              if !File.read(file2).match(/depends\s+["']#{dep}["']/)
                `echo '' >> "#{file2}"`
                `echo 'depends "#{dep}"' >> "#{file2}"`
              end
            end
          end
        end

        # fix encodings in cookbook files
        fix_encodings(cookbook_dir)
      end

    end

    def self.download_dependencies(cookbook, recipe, cookbook_dir=@@DEFAULT_COOKBOOKS_DIR, 
      overwrite_all=false, downloaded_so_far=[], parsed_so_far=[])

      includes = []
      if recipe

        include_commands = "((include_recipe)|(include_attribute)|(include_library))"

        recipe_files = []
        recipe = recipe.split("::")[1] if recipe.include?("::")
        recipe_files << File.join(cookbook_dir, cookbook, "recipes", "#{recipe}.rb")

        recipe_files.each do |recipe_file|

          if !File.exist?(recipe_file)
            puts "WARN: Expected recipe file does not exist: #{recipe_file}"
            return
          end
          file = File.read(recipe_file)
          parsed_so_far << "#{cookbook}::#{recipe}"
          file.scan(/(#{include_commands}[\s'"]+.*)$/) { |rec,total_match|
            tmp_includes = []
            # use eval(..) to handle cases like the following:
            # include_recipe %w{apache2 apache2::mod_php5}
            # include_recipe "apache2"
            # include_recipe ["apache2", "apache2::mod_php5"]
            rec.sub!(/#{include_commands}/, "tmp_includes=")
            begin
              eval(rec)
            rescue => ex
              puts "WARN: Unable to evaluate expression while parsing Chef recipe dependencies in file #{recipe_file}: '#{rec}': #{ex}"
              # this could be a case like the following:
              # include_recipe "nodejs::install_from_#{node['nodejs']['install_method']}"
              rec.scan(/["'](.*)::([^"']*)["']/) { |cb,rc|
                if rc.match(/^[a-z_\-A-Z0-9\.]+$/)
                  tmp_includes << "#{cb}::#{rc}"
                else
                  available_recipes_for_cookbook(cb, cookbook_dir).each do |rec_hash|
                    tmp_includes << "#{cb}::#{rec_hash['recipe_name']}"
                  end
                end
              }
            end
            tmp_includes = [tmp_includes] if !tmp_includes.kind_of?(Array)
            includes.concat(tmp_includes)
          }
       end

      end 

      # additionally, load dependencies from metadata files
      metadata_json = File.join(cookbook_dir, cookbook, "metadata.json")
      if File.exist?(metadata_json)
        #puts "DEBUG: Reading dependencies from '#{metadata_json}'"
        json = MarkupUtil.parse_json(File.read(metadata_json))
        if json["dependencies"]
          json["dependencies"].each do |dep_cb,dep_version|
            includes << dep_cb if !includes.include?(dep_cb)
          end
        end
      end
      metadata_rb = File.join(cookbook_dir, cookbook, "metadata.rb")
      #puts "DEBUG: Reading dependencies from '#{metadata_rb}'"
      if File.exist?(metadata_rb)
        file = File.read(metadata_rb)
        file.scan(/depends\s+["']([^"']+)["']/) { |dep_cb,total_string|
          includes << dep_cb if !includes.include?(dep_cb)
        }
      end

      puts "INFO: Recipe #{cookbook}::#{recipe} depends on: #{includes.inspect}" if !includes.empty?
      includes.each do |i|
        dep_recipe = i.include?("::") ? i.split("::")[1] : "default"
        dep_book = i.include?("::") ? i.split("::")[0] : i
        dep_file = File.join(cookbook_dir, dep_book, "recipes", "#{dep_recipe}.rb")
        if parsed_so_far.include?("#{dep_book}::#{dep_recipe}") ||
            downloaded_so_far.include?(dep_book)
          #puts "INFO: possible loop detected in cookbook dependencies for #{cookbook}::#{dep_recipe}: #{dep_book.inspect}. Stopping recursive lookup at this point."
        else
          downloaded_so_far << dep_book
          if !File.exist?(dep_file) || overwrite_all
            download_latest_cookbook(dep_book, cookbook_dir)
          end
          # recursively download cookbook dependencies
          #puts "DEBUG: Recursively downloading dependencies for '#{dep_book}::#{dep_recipe}'"
          download_dependencies(dep_book, dep_recipe, cookbook_dir, overwrite_all, downloaded_so_far, parsed_so_far)
        end
      end
    end

    def self.available_recipes_for_cookbook(cookbook_name, cookbooks_dir=@@DEFAULT_COOKBOOKS_DIR)
      result = []
      out = `ls #{cookbooks_dir}/#{cookbook_name}/recipes`
      out = out.strip.split(/\s+/)
      out.each do |file|
        recipe = file.sub(/(.*)\.rb/, '\1')
        result << { "recipe_name" => recipe }
      end
      return result
    end

    def self.available_recipes_from_opscode(cookbook_name, version="latest", 
        overwrite_downloads=false, target_dir=@@DEFAULT_OPSCODE_TMP_DIR)
      if target_dir
        FileUtils.mkpath(target_dir) if !File.directory?(target_dir)
        # check if cookbook folder already exists
        cookbook_folder = File.join(target_dir, cookbook_name)
        if File.directory?(cookbook_folder) && overwrite_downloads
          FileUtils.rm_rf(cookbook_folder)
        end
        if !File.directory?(cookbook_folder)
          download_cookbook_version(cookbook_name, version, target_dir, true)
        end
        return available_recipes_for_cookbook(cookbook_name, target_dir)
      else
        Util.mktmpdir() { |file|
          download_cookbook_version(cookbook_name, version, file, true)
          return available_recipes_for_cookbook(cookbook_name, file)
        }
      end
    end

    def self.runtime_resource_sourcecode(resource)
      return resource.to_text if resource.respond_to?("to_text")
    end

    def self.available_cookbooks_from_opscode(query_details=false, overwrite_downloads=false)
      result = []
      tmpmap = {}
      max = 1000
      start = 0
      while start < max
        url = "#{OPSCODE_API_URL}cookbooks?start=#{start}&items=100"
        puts url
        json = `curl '#{url}' 2> /dev/null`
        books = MarkupUtil.parse_json(json.strip)
        if books["items"].kind_of?(Array)
          result.concat(books["items"])
          books["items"].each do |item|
            tmpmap[item["cookbook_name"]] = item
          end
        end
        max = books["total"].to_i if books["total"] && books["total"].to_i > 0 && books["total"].to_i < 2000
        start += 100
      end
      if query_details
        # download all (!) cookbooks from opscode
        download_all_from_opscode(nil, overwrite_downloads)
        # get information about all resources
        resources = parse_all_resources("*.rb")

        begin
          html = `curl '#{OPSCODE_SEARCH_URL}?page=1' 2> /dev/null`
          doc = Toaster::MarkupUtil.parse_xml(html, true)

          num_pages = REXML::XPath.match(doc, "//a[text()='Next']/preceding-sibling::a[1]/text()")
          num_pages = "#{num_pages[0]}".to_i
          (2..num_pages).each do |page_num|
            REXML::XPath.match(doc, "//ul[@class='cookbook-list']/li").each do |cbxml|
              cbxml = REXML::Document.new cbxml.to_s
              title = REXML::XPath.match(cbxml, "//a[@class='title']/text()")[0]
              title = "#{title}".strip
              if tmpmap[title]
                ratings = REXML::XPath.match(cbxml, "//span[@class='count']/text()")[0]
                downloads = REXML::XPath.match(cbxml, "//div[@class='downloads']/text()")[0]
                followers = REXML::XPath.match(cbxml, "//div[@class='followers']/text()")[0]
                platforms = REXML::XPath.match(cbxml, "//div[@class='platforms']/p/text()")[0]
                category = REXML::XPath.match(cbxml, "//div[@class='category']/a/text()")[0]
                ratings = "#{ratings}".gsub(/(\\n)|\s*/, "").gsub(/rating(s)*/, "").strip.to_i
                downloads = "#{downloads}".gsub(/(\\n)|\s*/, "").gsub(/download(s)*/, "").strip.to_i
                followers = "#{followers}".gsub(/(\\n)|\s*/, "").gsub(/follower(s)*/, "").strip.to_i
                platforms = "#{platforms}".gsub(/\\n/, "").gsub(/Platforms:/, "").gsub("&gt;", ">").strip
                category = "#{category}".gsub(/\\n/, "").gsub("&amp;", "&").strip
                #puts "ratings #{title}: #{ratings} - #{downloads} - #{followers} - #{platforms} - #{category}"
                tmpmap[title]["_ratings"] = ratings
                tmpmap[title]["_downloads"] = downloads
                tmpmap[title]["_followers"] = followers
                tmpmap[title]["_platforms"] = platforms
                tmpmap[title]["_category"] = category
              end
            end
            html = `curl '#{OPSCODE_SEARCH_URL}?page=#{page_num}' 2> /dev/null`
            doc = Toaster::MarkupUtil.parse_xml(html, true)
          end
          result.each do |cbook|
            fetch_cookbook_details(cbook["cookbook_name"], cbook, resources)
          end
        rescue Object => exc
          puts "WARN: Exception when querying cookbook details from #{OPSCODE_SEARCH_URL}?page=1: #{exc} - #{exc.backtrace}"
        end
        # sort results
        result.sort! { |a,b| 
          a["_downloads"] = 0 if !a["_downloads"]
          b["_downloads"] = 0 if !b["_downloads"]
          a["_average_rating"] = 0 if !a["_average_rating"]
          b["_average_rating"] = 0 if !b["_average_rating"]
          (b["_downloads"] <=> a["_downloads"]) != 0 ? 
            b["_downloads"] <=> a["_downloads"] : 
            b["_average_rating"] <=> a["_average_rating"]
        }
        result.each_with_index do |cb,idx|
          cb["_position"] = idx + 1
        end
      end
      return result
    end

    def self.fetch_cookbook_details(cookbook_name, cbook={}, resources={}, overwrite_downloads=false)
      url = "#{OPSCODE_API_URL}cookbooks/#{cookbook_name}/"
      json = `curl '#{url}' 2> /dev/null`
      details = MarkupUtil.parse_json(json.strip)
      if !details['latest_version']
        if details['error_code']
          raise "WARN: Unable to fetch cookbook metadata from #{url}: " +
              "#{details['error_code']} - #{details['error_messages']}"
        end
      end
      latest_version = details['latest_version'].gsub(/.*\/([^\/]+)/, '\1')
      cbook['_latest_version'] = latest_version
      versions = []
      details['versions'].each do |ver|
        versions << ver.gsub(/.*\/([^\/]+)/, '\1')
      end
      cbook["_versions"] = versions
      if !details["average_rating"].nil?
        cbook["_average_rating"] = details["average_rating"]
      end
      # load all recipe names for this cookbook
      if !cbook["_recipes"]
        cb_name = cookbook_name
        recipes = Toaster::ChefUtil.available_recipes_from_opscode(
            cb_name, cbook["_latest_version"], overwrite_downloads)
        cbook["_recipes"] = {} if !cbook["_recipes"]
        recipe_names = []
        recipes.each do |r|
          rec_name = r["recipe_name"]
          recipe_names << rec_name
          cbook["_recipes"][rec_name] = {}
          cbook["_recipes"][rec_name]["_resource_names"] = []
          if resources[cb_name] && resources[cb_name][rec_name]
            if resources[cb_name][rec_name]["_possibly_non_idempotent"]
              cbook["_possibly_non_idempotent"] = true
            end
            resources[cb_name][rec_name]["resources"].each do |line,code|
              if code
                code = code.split("\n")[0]
                resrc_name = code.gsub(/^\s*([a-zA-Z0-9_\-]*)\s+(.*)\s+((do)|\{).*$/, '\1[\2]')
                resrc_name = resrc_name.strip
                #puts "TRACE: resource name: #{resrc_name}"
                cbook["_recipes"][rec_name]["_resource_names"] << resrc_name
              end
            end
          else
            puts "WARN: Did not find detailed Chef resource information for '#{cb_name}'::'#{rec_name}'"
          end
        end
        cbook["_recipe_names"] = recipe_names
      end
      return cbook
    end

    def self.available_cookbook_versions(cookbook_name)
      fetch_cookbook_details(cookbook_name)["_versions"].uniq
    end

    def self.download_all_from_opscode(target_dir=@@DEFAULT_OPSCODE_TMP_DIR, overwrite_downloads=false)
      target_dir = "/tmp/opscode_cookbooks/" if !target_dir
      if overwrite_downloads || !File.exist?(target_dir)
        `mkdir -p "#{target_dir}"`
        cookbooks = available_cookbooks_from_opscode()
        cookbooks.each do |cb|
          cookbook_name = cb["cookbook_name"]
          #puts "downloading cookbook #{cookbook_name} to #{target_dir}"
          download_cookbook_version(cookbook_name, "latest", target_dir, true)
        end
      end
    end
  
    def self.parse_resources(cookbook, recipe_name, version="latest", 
        result = {}, cookbook_dir=@@DEFAULT_OPSCODE_TMP_DIR)
      recipe_file = "#{cookbook_dir}/#{cookbook}/recipes/#{recipe_name}.rb"
      attributes_file = "#{cookbook_dir}/#{cookbook}/attributes/#{recipe_name}.rb"
      recipe_file_relative = "#{cookbook}/recipes/#{recipe_name}.rb"
      attributes_source = File.exist?(attributes_file) ? File.read(attributes_file) : ""

      if !File.exist?(recipe_file)
        download_cookbook_version(cookbook, version, cookbook_dir)
      end

      puts "TRACE: Scanning recipe file: #{recipe_file}"
      resource_lines = []
      script_resource_lines = []
      result[cookbook] = {} if !result[cookbook]
      result[cookbook][recipe_name] = {} if !result[cookbook][recipe_name]
      result[cookbook][recipe_name]["file"] = recipe_file_relative
      result[cookbook][recipe_name]["resources"] = {} if !result[cookbook][recipe_name]["resources"]
      result[cookbook][recipe_name]["resource_objs"] = {} if !result[cookbook][recipe_name]["resource_objs"]

      # resource names taken from 
      # http://docs.opscode.com/resource.html
      # http://wiki.opscode.com/display/chef/Resources
      resource_names = ["apt_package", "bash", "chef_gem", "csh", "cron", "deploy", 
        "directory", "dpkg_package", "easy_install_package", "env", "erlang_call", "erl_call", 
        "execute", "file", "freebsd_package", "gem_package", "git", "group", "http_request", 
        "ifconfig", "link", "log", "macports_package", "mdadm", "mount", "ohai", "package", "perl",
        "portage_package", "powershell_script", "python", "remote_directory", "remote_file", "route",
        "rpm_package", "ruby_block", "ruby", "scm", "script", "service", "solaris_package", 
        "template", "user", "yum_package", "zypper_package",
        "mysql_service" # additional resource types
        ]
      script_resource_names = ["execute", "bash", "script", "ruby_block", "csh"]

      File.open(recipe_file) do |io|
        io.each_with_index { |line,idx| 
          idx += 1 # index is 0-based, line should be 1-based
          if line.match(/^(\s*[0-9a-zA-Z_]+\s*=\s*)?\s*((#{resource_names.join(")|(")}))((\s+)|($)|(\s*\())/)
            resource_lines << idx
          elsif line.match(/execute.*do/) && !line.match(/^\s*#/)
            puts "WARN: NO resource line: #{line}"
          end
        }
        resource_lines.each do |line|
          code = read_sourcecode_from_line(recipe_file, line)
          if !code
            puts "WARN: Could not parse code file #{recipe_file} : #{line}"
          else
            resource_obj = Chef::ResourceInspector.get_resource_from_source(code, attributes_source)
            result[cookbook][recipe_name]["resources"][line] = code
            result[cookbook][recipe_name]["resource_objs"][line] = resource_obj
            if !code.match(/not_if\s*/) && !code.match(/only_if\s*/)
              resource_type = code.split("\n")[0].gsub(/^\s*([a-zA-Z0-9_\-]*)\s+(.*)\s+((do)|\{).*$/, '\1')
              if script_resource_names.include?(resource_type)
                result[cookbook][recipe_name]["_possibly_non_idempotent"] = true
              end
            end
          end
        end
      end
      return result
    end

    def self.parse_all_resources(recipe_pattern="default.rb", cookbook_dir=@@DEFAULT_OPSCODE_TMP_DIR)
      # cookbook_name -> recipe_file -> line_no -> resource_code
      result = {}
      scanned_files = 0
      Dir.entries(cookbook_dir).each do |cookbook|
        if cookbook.match(/^[a-zA-Z0-9_\-]+$/)
          recipe_dir = "#{cookbook_dir}/#{cookbook}/recipes"
          Dir["#{recipe_dir}/#{recipe_pattern}"].each do |recipe_file|
            recipe_name = recipe_file.gsub(/.*\/([^\/]+)\.rb$/, '\1')
            parse_resources(cookbook, recipe_name, "latest", result, cookbook_dir)
            scanned_files += 1
          end
        end
      end
      puts "INFO: Scanned #{scanned_files} files for resource information."
      return result
    end

    def self.diff_cookbook_versions(cookb, v1, v2)
      v1.gsub!(".", "_")
      v2.gsub!(".", "_")
      target_dir = "/tmp/toaster/tmp_chef_cb/#{cookb}"
      dir1 = "#{target_dir}/#{v1}"
      dir2 = "#{target_dir}/#{v2}"
      `mkdir -p '#{target_dir}'`
      if !File.directory?(dir1)
        `mkdir -p '#{dir1}'`
        download_cookbook_version(cookb, v1, dir1)
      end
      if !File.directory?(dir2)
        `mkdir -p '#{dir2}'`
        download_cookbook_version(cookb, v2, dir2)
      end
      return Util.diff_dirs(dir1, dir2)
    end

  end
end
