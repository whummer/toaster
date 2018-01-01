#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'toaster/chef/chef_node_inspector'

# $old_node and $new_node must be set before calling this script!

class ::Chef
  class Node
    def attributes_proxy=(attrs)
      @attributes_proxy = attrs
    end
    def method_missing(sym, *args, &block)
      @attributes_proxy.send(sym, *args, &block)
    end
  end

  class Resource
    def method_missing(method_symbol, *args, &block)
      # code copied from chef/resource.rb
      if enclosing_provider && enclosing_provider.respond_to?(method_symbol)
        enclosing_provider.send(method_symbol, *args, &block)
      else
        $new_node.send(method_symbol, *args, &block)
      end
    end
    def resources(*args)
      begin
        super
      rescue Object
        nil
      end
    end
    def notifies(action, resource_spec, timing=:delayed)
      begin
        super
      rescue Object
        nil
      end
    end
  end

  module Mixin
    module ParamsValidate
      def validate(opts, map)
        begin
          super
        rescue Object
          nil
        end
      end
    end
  end

  module DSL
    module Recipe
      #alias_method :old_method_missing, :method_missing
      $old_mm = ::Chef::DSL::Recipe.instance_method(:method_missing)
      def attributes_proxy=(attrs)
        @attributes_proxy = attrs
      end
      def respond_to?(sym, included_privates = false)
        true
      end
      def respond_to_missing?(sym, included_privates = false)
        true
      end
      def instance_eval(string, filename=nil, lineno=nil, &block)
        begin
          super
        rescue Object => ex
          puts "WARN: cannot run instance_eval on recipe: #{ex}"
        end
      end
#      def build_resource(type, name, created_at=nil, &resource_attrs_block)
#        if !name
#          name = "__unnamed__"
#        end
#        super(type, name, created_at, &resource_attrs_block)
#      end
      def method_missing(method_symbol, *args, &block)
        #puts "method_missing:"
        puts method_symbol
        begin

          # code copied from chef/dsl/recipe.rb
          
          # If we have a definition that matches, we want to use that instead.  This should
          # let you do some really crazy over-riding of "native" types, if you really want
          # to.
          if has_resource_definition?(method_symbol)
            evaluate_resource_definition(method_symbol, *args, &block)
          elsif have_resource_class_for?(method_symbol)
            # Otherwise, we're rocking the regular resource call route.
            declare_resource(method_symbol, args[0] && !args[0].empty? ? args[0] : "__some_name__", caller[0], &block)
          else
            begin
              super
            rescue NoMethodError
              raise NoMethodError, "No resource or method named `#{method_symbol}' for #{describe_self_for_error}"
            rescue NameError
              raise NameError, "No resource, method, or local variable named `#{method_symbol}' for #{describe_self_for_error}"
            end
          end

          #old_method_missing(method_symbol, args, block)
          #super
          if caller.size > 250
            puts $old_mm.object_id
            puts "--"
            puts ::Chef::DSL::Recipe.instance_method(:method_missing).object_id
            puts "-------"
            return nil
          end
          # puts "--->"
          # puts self
          # $old_mm.bind(self).(method_symbol, *args, &block)
        rescue Object => ex
#                      begin
            #puts ex
            #puts ex.backtrace.join(" \n")
            proxy = @attributes_proxy ? @attributes_proxy : $new_node
            #puts "proxy (in new line):"
            #puts proxy
            #puts method_symbol
            proxy.send(method_symbol, *args, &block)
#                      rescue Object => ex1
#                        puts ex1
#                        puts ex1.backtrace.join(" \n")
#                        puts "----"
#                        puts caller
#                      end
        end
      end
    end
  end
end

            