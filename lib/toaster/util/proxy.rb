
# Generic proxy implementation, based on:
# http://www.binarylogic.com/2009/08/07/how-to-create-a-proxy-class-in-ruby/

module Toaster
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
