module Citac
  module Providers
    def self.get(name)
      @providers = Hash.new unless @providers

      raise "Unknown provider '#{name}'." unless @providers.include? name
      @providers[name]
    end

    def self.register(name, klass)
      @providers = Hash.new unless @providers

      raise "Provider '#{name}' already registered." if @providers.include? name
      @providers[name] = klass
    end
  end
end