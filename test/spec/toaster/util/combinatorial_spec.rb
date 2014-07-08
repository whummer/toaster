

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'toaster/util/combinatorial'

include Toaster

describe Combinatorial, "::combine" do

  def test_combine(list, length, only_successive=false)
    #TimeStamp.add
    combs = Combinatorial.combine(list.to_a, length, only_successive)
    #puts "#{combs.size} Combinations"
    #puts "#{combs.inspect}" if combs.size < 200
    #TimeStamp.add_and_print("generate combinations of list #{list} with length #{length}")
    return combs
  end

  def test_skip(list, length, only_successive=false)
    combs = Combinatorial.skip(list.to_a, length, only_successive)
    return combs
  end

  def set(array)
    res = Set.new
    array.each do |i|
      res << i
    end
    return res
  end

  it "correctly builds list of combinations" do

    test_combine([1], 2).should eq(set([]))
    test_combine([1,2], 2).should eq(set([[1,2]]))
    test_combine((1..3), 2).size.should eq(3)
    test_combine((1..4), 2).size.should eq(6)
    test_combine((1..10), 2).size.should eq(45)
    test_combine((1..10), 4).size.should eq(210)
    test_combine((1..10), 7).size.should eq(120)
    test_combine((1..20), 2).size.should eq(190)
    test_combine((1..30), 2).size.should eq(435)
    test_combine((1..30), 3).size.should eq(4060)
    test_combine((1..10), 2, true).size.should eq(9)
    test_combine((1..30), 2, true).size.should eq(29)
    test_combine((1..30), 3, true).size.should eq(28)

  end

  it "correctly builds combinations by skipping elements from a list" do

    test_skip([1], 2).should eq(set([]))
    test_skip([1,2], 1).should eq(set([[1],[2]]))
    test_skip((1..3), 2).should eq(set([[1],[2],[3]]))
    test_skip((1..3), 2, true).should eq(set([[1],[3]]))
    test_skip((1..4), 2).should eq(set([[1,2],[1,3],[1,4],[2,3],[2,4],[3,4]]))
    test_skip((1..4), 2, true).should eq(set([[1,2],[1,4],[3,4]]))
    test_skip((1..5), 3, true).should eq(set([[1,2],[1,5],[4,5]]))
    test_skip((1..10), 2, true).size.should eq(9)
    test_skip((1..10), 3).size.should eq(120)

  end

end
