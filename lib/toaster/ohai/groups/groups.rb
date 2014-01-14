
################################################################################
# (c) Waldemar Hummer
################################################################################

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "groups"
groups Mash.new

# build list of groups
out = `awk -F":" '{ print $1 " : " $3 }' /etc/group`
out.split("\n").each do |line|
  parts = line.split(" : ")
  name = parts[0]
  gid = parts[1]
  groups[name] = { "gid" => gid }
end
