module Citac
  module Utils
    module RangeParser
      def self.parse(value, min, max)
        return (min..max).to_a if value.nil? || value == '*'
        if value.include? '-'
          first, last = value.split '-', 2

          unless first == '' || first == '*'
            first = first.to_i
            min = first if first > min
          end

          unless last == '' || last == '*'
            last = last.to_i
            max = last if last < max
          end

          (min..max).to_a
        else
          [value.to_i]
        end
      end
    end
  end
end