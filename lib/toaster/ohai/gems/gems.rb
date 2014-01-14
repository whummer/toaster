

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "gems"
gems Mash.new

output = `gem list --local`
# build list of gems
output.split("\n").each do |line|
  if line.strip != "" && line[0]  != "*"
    name = line.gsub(/^([a-z0-9A-Z\-]+) .*/, '\1')
    versions = line.gsub(/^.*\((.*)\)/, '\1')
    versions = versions.split(/[ ,]+/)
    gems[name] = versions
  end
end
