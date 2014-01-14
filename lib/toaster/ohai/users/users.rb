

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "users"
users Mash.new

# build list of users
out = `awk -F":" '{ print $1 " : " $3 }' /etc/passwd`
out.split("\n").each do |line|
  parts = line.split(" : ")
  name = parts[0]
  uid = parts[1]
  users[name] = { "uid" => uid }
end
