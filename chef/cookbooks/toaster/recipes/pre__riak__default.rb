# recipe riak::default uses some illegal statements 
# (under Chef 11) which we fix here using dynamic property lookup:
node.set["riak"]["kv"] = Hash.new(node["riak"]["kv"])
node.set["riak"]["kv"]["storage_backend"] = :riak_kv_bitcask_backend
node.set["riak"]["sasl"]["errlog_type"] = :error
class DynamicAttrLookup
  def initialize(node_value)
    @node_value = node_value
  end
  def method_missing(m, *args, &block)
    if @node_value.respond_to?(m)
      @node_value.send(m, *args)
    else
      DynamicAttrLookup.new(@node_value[m])
    end
  end
end
class ::Chef
  class Node
    def riak
      DynamicAttrLookup.new(self["riak"])
    end
    def ip_address
      DynamicAttrLookup.new(self["ip_address"])
    end
    class ImmutableMash
      def delete(arg1)
        super(arg1)
      end
    end
  end
    module DSL
      module Recipe
        def default
          puts "Called default!! #{node.set}"
          DynamicAttrLookup.new(node.set)
        end
      end
    end
end