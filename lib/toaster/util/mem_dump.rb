
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
# 

module Toaster
  class MemDump
    def self.print_dump(pattern=".*")
      Util.write("/tmp/foo.dump.out", "lala", true)
      res = {}
      count = 0
      ObjectSpace.each_object do |obj|
        cls = obj.class
        res[cls] = res[cls] ? res[cls] + 1 : 1
        count += 1
        print "Counted #{count} objects" if (count % 100000 == 0)
      end
      array = []
      res.each do |clazz,count|
        name = clazz.name
        if name.match(/#{pattern}/)
          array << [clazz,count]
        end
      end
      # sort by decreasing number of instances
      array.sort! { |o1,o2| o2[1] <=> o1[1] }
      array = array[0..50]
      out = ""
      array.each do |i|
        tmp = "#{i[0]} \t- Class #{i[0]}"
        out += tmp
        puts tmp
      end
      Util.write("/tmp/foo.dump.out", out, true)
      return array
    end
  end
end
