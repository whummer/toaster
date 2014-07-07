

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'rubygems'
require 'json'
require 'rexml/document'
require 'hashdiff'
require 'active_support/all'
require 'jsonpath'
require 'toaster/util/util'

include Toaster

module Toaster
  class MarkupUtil

    JSON_MAP_ENTRY_NAME = "json--map--entry"
    JSON_MAP_ENTRY_KEY = "key"
    JSON_MAP_ENTRY_VALUE = "value"

    def self.rectify_keys(json)
      newKey = JSON_MAP_ENTRY_NAME
      if json.kind_of?(Array) || json.kind_of?(Set)
        json.each do |obj|
          rectify_keys(obj)
        end
      elsif json.kind_of?(Hash)
        keys = json.keys.dup
        keys.each do |key|
          val = json[key]
          rectify_keys(val)
          if !key.kind_of?(String) || key.include?("/") || 
                !key.match(/^[a-zA-Z_][a-zA-Z_0-9\-]*$/)

            # !json.respond_to?("push") may occur if the hash is 
            # actually an instance of ChefNodeInspector!
            if !json[newKey] || !json[newKey].respond_to?("push")
              json[newKey] = []
            end
            json[newKey].push({
              JSON_MAP_ENTRY_KEY => key,
              JSON_MAP_ENTRY_VALUE => val
            })
            json.delete(key)
          end
        end
      end
      return json
    end

    def self.clone(hash)
      return nil if !hash
      return parse_json(hash.to_json())
    end
    
    def self.to_json(hash)
      return hash.to_json()
    end

    def self.to_pretty_json(hash)
      return JSON.pretty_generate(hash)
    end

    # recursively merge two hashes into one hash
    def self.rmerge!(hash1, hash2, unique_array_values = false)
      hash1.merge!(hash2) do |key, oldval, newval|
        if oldval.kind_of?(Hash)
          MarkupUtil.rmerge!(oldval, newval)
        elsif oldval.kind_of?(Array)
          oldval.concat(newval)
          if unique_array_values
            oldval.uniq!
          end
          oldval # return oldval
        else
          newval # return newval
        end
      end
    end

    def self.remove_properties(json, keys_path)
      if keys_path.size == 1
        json.delete(keys_path[0])
        return
      end
      if json.kind_of?(Array)
        json.each do |j|
          remove_properties(j,keys_path.dup)
        end
      else
        this_key = keys_path.shift()
        json.each do |key,val|
          if key == this_key || key.match(this_key).to_s == key
            remove_properties(json[key], keys_path.dup)
          end
        end
      end
    end

    def self.json_to_xml(json)
      rectify_keys(json)
      if json.respond_to?("to_xml")
        return json.to_xml
      end
      str = json.to_s
      return parse_json(str).to_xml
    end

    def self.parse_json(str)
      return JSON.parse(str)
    end

    def self.json_diff(json1, json2)
      diff = JsonDiff.new
      differences = diff.different?(json1, json2)
      puts "JSON differences: #{JSON.pretty_generate(differences)}"
      differences
    end

    def self.parse_xml(xml, use_tidy=false)
      begin
        REXML::Document.new(xml)
      rescue => ex
        file = "/tmp/toaster.doc.error.tmp.xml"
        if use_tidy
          # include tidy only here (not at top level), because in a 
          # Chef run it is incompatible with some ruby versions..
          require "tidy"
          begin
            puts "INFO: cleaning up document using XML tidy..."
            html_tidy = nil
            Tidy.open({:show_warnings => true, :output_xml => true}) do |tidy|
              html_tidy = tidy.clean(xml)
            end
            return REXML::Document.new(html_tidy.to_s)
          rescue => ex1
            puts "Unable to parse XML document using XML Tidy, writing contents to #{file}"
            Util.write(file, xml, true)
            raise ex1
          end
        else
          puts "Unable to parse XML document, writing contents to #{file}"
          Util.write(file, xml, true)
          raise ex
        end
      end
    end

    def self.xml_diff_large_docs(xml1, xml2)
      doc1 = parse_xml(xml1)
      doc2 = parse_xml(xml2)
      root1 = doc1.elements[1]
      root2 = doc2.elements[1]
      if root1.elements.size != root2.elements.size
        return {xml1 => xml_diff(xml1, xml2)}
      end
      result = {}
      (1..root1.elements.size).each do |i|
        el1 = root1.elements[i].to_s
        el2 = root2.elements[i].to_s
        if el1 != el2
          diff = xml_diff(el1, el2)
          result[el1] = diff
        end
      end
      result
    end

    def self.eliminate_inserted_map_entries!(hash)
      if hash.kind_of?(Hash)
        hash.keys.dup.each do |k|
          if k == JSON_MAP_ENTRY_NAME
            child = hash[k]
            entries = child.kind_of?(Array) ? child : [child]
            entries.each do |e|
              key = e[JSON_MAP_ENTRY_KEY]
              value = e[JSON_MAP_ENTRY_VALUE]
              hash.delete(JSON_MAP_ENTRY_NAME)
              if hash[key] && hash[key] != value
                raise "Cannot convert hash because element '#{key}' already exists at this level."
              end
              hash[key] = value
              eliminate_inserted_map_entries!(hash[key])
            end
          else
            eliminate_inserted_map_entries!(hash[k])
          end
        end
      elsif hash.kind_of?(Array)
        hash.each do |e|
          eliminate_inserted_map_entries!(e)
        end
      end
      return hash
    end

    def self.get_value_by_path(hash, path_expression, do_eliminate_map_entries=false)
      #puts "<pre>evaluating path expression: '#{path_expression}' for object #{hash}</pre>"
      if !hash.kind_of?(Hash) 
        raise "Expected Hash object to select value by given path, but sgot: #{hash.class}"
      end
      if do_eliminate_map_entries
        eliminate_inserted_map_entries!(hash)
      end
      path = JsonPath.new(path_expression)
      result = path.on(hash)
      if result.kind_of?(Array)
        if result.size == 1
          result = result[0]
        elsif result.empty?
          if hash[path_expression]
            return hash[path_expression]
          else
            return :UNDEFINED_VALUE
          end
        end
      end
      return result
    end

    def self.delete_value_by_path(hash, path_expression, do_eliminate_map_entries=false)
      if do_eliminate_map_entries
        eliminate_inserted_map_entries!(hash)
      end
      keys_path = get_keys_path_from_expr(path_expression)
      remove_properties(hash, keys_path)
    end

    def self.set_value_by_path(json, keys_path, value)
      if !keys_path.kind_of?(Array)
        keys_path = get_keys_path_from_expr(keys_path)
      end
      if keys_path.size == 1
        json[keys_path[0]] = value
        return
      end
      if json.kind_of?(Array)
        json.each do |j|
          set_value_by_path(j, keys_path.dup, value)
        end
      else
        this_key = keys_path.shift()
        json.each do |key,val|
          if key == this_key || key.match(this_key).to_s == key
            set_value_by_path(json[key], keys_path.dup, value)
          end
        end
      end
    end

    class DynTravers
      attr_reader :path
      def initialize(expr)
        @path = []
        eval(expr)
      end
      def method_missing(m, *args, &block)
        if m == :[]
          @path << args[0]
        else
          @path << m.to_s
        end
        self
      end
    end
    def self.get_keys_path_from_expr(path_expression)
      path_expression = path_expression.gsub(/\.'([^\'\[]*)'/, '[\'\1\']')
      path_expression = path_expression.gsub(/\.([0-9]+)$/, '[\1]')
      path = DynTravers.new(path_expression).path
      return path
    end

    #
    # Converts an attribute "path" 
    # from "dot notation" (e.g., 'foo'.'bar')
    # to "array notation" (e.g., ['foo']['bar']) 
    #
    def self.convert_dot_to_array_notation(name)
      name = name.gsub(/'\.'/, "']['").gsub(/(^|[^\.])'/,'\1[\'').gsub(/'($|[^\.])/,'\']\1')
      name = name.gsub(/([a-zA-Z0-9_])\.([a-zA-Z0-9_])/, '\1\'][\'\2').
          gsub(/(^)([a-zA-Z0-9_])/,'[\'\2').
          gsub(/([a-zA-Z0-9_])($)/,'\1\']')
      return name
    end

    #
    # Converts a Chef attribute "path" from "array notation" (e.g., ['foo']['bar']) 
    # to "dot notation" (e.g., 'foo'.'bar')
    #
    def self.convert_array_to_dot_notation(name) 
      name = name.gsub(/"/, "'").gsub(/'\]\['/, "'.'").gsub(/(^|[^\]])\[/,'\1')
      return name.gsub(/\]($|[^\[])/,'\1').gsub(/\]\[:/,".:")
    end

    def self.xml_diff(xml1, xml2)
      
      # check if the document comparison is "feasible" with the 
      # XML diff tool set we are currently using.
      doc1 = REXML::Document.new xml1
      doc2 = REXML::Document.new xml2
      num_els1 = REXML::XPath.match(doc1, "count(//*)")
      num_els2 = REXML::XPath.match(doc2, "count(//*)")
        num_els1 = num_els1[0] if num_els1[0]
        num_els2 = num_els2[0] if num_els2[0]
        if num_els1 > 500 || num_els2 > 500
          return <<-EOC
<OTA_UpdateRQ>
  <Position XPath="/*">
  <Subtree Operation="error">
    Too many elements in XML documents to compare: #{num_els1}/#{num_els2}
    </Subtree>
  </Position>
</OTA_UpdateRQ>
          EOC
        end

        file1 = file2 = ""
      Tempfile.open("xml1") do |tmp1|
        tmp1.write(xml1)
        file1 = tmp1.path
        Tempfile.open("xml2") do |tmp2|
          tmp2.write(xml2)
          file2 = tmp2.path
          tmp1.close
          tmp2.close
          cmd = "cd #{File.expand_path(File.dirname(__FILE__))} && ./xmldiff.sh 'file://#{file1}' 'file://#{file2}'"
          system("cp #{file1} /tmp/xmldiff.file1.xml")
          system("cp #{file2} /tmp/xmldiff.file2.xml")
          #puts "executing: #{cmd}"
          output = `#{cmd}`
          begin
            diff = output[output.index("<OTA_UpdateRQ")..-1]
            return diff
          rescue => ex
            puts "WARN: Unable to compute XML diff: #{ex}"
            puts "-----"
            puts cmd
            puts "-----"
            puts output
            puts "-----"
            puts xml1
            puts "-----"
            puts xml2
            puts "-----"
            return nil
          end
        end
      end
    end

    def self.hash_diff_as_prop_changes(h1, h2)
      require 'toaster/model/state'
      result = []

      hashdiffs = hashdiff(h1, h2)
      #puts "hashdiffs: #{hashdiffs}"
      hashdiffs.each do |d|
        c = StateChange.new
        c.action = d[0] == "-" ? StateChange::ACTION_DELETE :
                   d[0] == "+" ? StateChange::ACTION_INSERT :
                   d[0] == "~" ? StateChange::ACTION_MODIFY : nil
        c.property = d[1]

        #fix keys generated by hashdiff
        c.property.gsub!(".['", "['")
        c.property.gsub!('.["', '["')

        c.value = d[2]
        if d[0] == "~"
          c.old_value = d[2]
          c.value = d[3]
        end
        if c.action == StateChange::ACTION_INSERT && c.value.nil?
          # if the newly inserted value is nil, do not report a state change!
        else
          result << c
        end
      end

      return result
    end

    def self.fix_keys_for_hashdiff(h)
      if h.kind_of?(Hash)
        h.keys.dup.each do |k|
          v = h[k]
          fix_keys_for_hashdiff(v)
          if !k.match(/^[a-zA-Z0-9_]+$/)
            h.delete(k)
            newkey = "['#{k}']"
            h[newkey] = v
          end
        end
      elsif h.kind_of?(Array)
        h.each do |e|
          fix_keys_for_hashdiff(e)
        end
      end
    end

    def self.hashdiff(hash1, hash2)
      fix_keys_for_hashdiff(hash1)
      fix_keys_for_hashdiff(hash2)
      result = HashDiff.diff(hash1, hash2)
      return result
    end

    def self.xpath_to_attr_name(name)
      name = name.sub("/hash/", "")
      name = name[1..-1] if name[0] == "/"
      name = name[0..name.index("self::node()")-2] if name.include?("self::node()")
      name = name.gsub("/",".")
      return name
    end

    def self.xml_array_to_json(xml_array, treat_as_map=false)
      result = treat_as_map ? {} : []
      xml_array.each do |x|
        part = xml_to_json(x)
        if treat_as_map
          
        else
          result.push(part)
        end
      end
      return result
    end

    def self.xml_to_json(xml)
      return Hash.from_xml(xml.to_s)
    end

  end
end
