require_relative 'model'

module Citac
  class ConfigurationSpecification
    def self.parse(io)
      spec = nil

      io.each do |line|
        if spec
          resources = line.split(/\s/).map {|x| Integer(x)}
          to = resources.first
          resources.drop(1).each do |from|
            spec.add_dep from, to
          end
        else
          spec = ConfigurationSpecification.new Integer(line)
        end
      end

      spec
    end
  end
end