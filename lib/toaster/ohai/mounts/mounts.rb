

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "mounts"
mounts Mash.new

output = `mount`
# build list of mounts
output.split("\n").each do |line|
  if line.strip != "" && line[0]  != "*"
    pattern = /(.*) on (.*) type (.*) \((.*)\)/
    dev = line.gsub(pattern, '\1')
    mountpoint = line.gsub(pattern, '\2')
    type = line.gsub(pattern, '\3')
    options = line.gsub(pattern, '\4')
    mounts[mountpoint] = {
      "device" => dev,
      #"mountpoint" => mountpoint,
      "type" => type,
      "options" => options
    }
  end
end
