

include Toaster

module Toaster

  #
  # Utility methods for combinatorial test design.
  #
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  #
  class Combinatorial

    def self.combine(list, length=nil, successive=false, results=Set.new, current=[])
      length = list.size if !length
      if current.size == length
        results << current
        return results
      end
      return results if list.empty?
      next_item = list[0]
      list_new = list[1..-1]
      cur_new = current.dup
      cur_new << next_item
      combine(list_new, length, successive, results, cur_new)
      if current.empty? || !successive
        cur_new1 = current.dup
        combine(list_new, length, successive, results, cur_new1)
      end
      return results
    end

    def self.skip(list, length=nil, successive=false, results=Set.new, current=[], original_size=nil, skipped_so_far=0)
      length = 0 if !length
      original_size = list.size if !original_size
      if current.size == original_size - length
        results << current
        return results
      end
      return results if list.empty?
      next_item = list[0]
      list_new = list[1..-1]
      cur_new = current.dup
      skip(list_new, length, successive, results, cur_new, original_size, skipped_so_far+1)
      if skipped_so_far == 0 || !successive || skipped_so_far >= length
        cur_new1 = current.dup
        cur_new1 << next_item
        skip(list_new, length, successive, results, cur_new1, original_size, skipped_so_far)
      end
      return results
    end

    private

    def initialize
    end
  end
end
