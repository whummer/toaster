
################################################################################
# (c) Waldemar Hummer
################################################################################

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#



# return a list of properties which should not be 
# considered for test case generation or computation
# of the state transition graphs
def ignore_properties__files()
  return [
    /(')*files.*\.(')*ctime(')*/, # file creating time
    /(')*files.*\.(')*mtime(')*/ # file modification time
  ]
end

def diff__files(f1, f2)
  # not implemented
  return nil
end

def reduce__files(f1, f2)
  # not implemented
  return nil
end
