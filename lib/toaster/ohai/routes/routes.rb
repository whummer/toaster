

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "routes"
routes Mash.new

output = `route -n`
# build list of routes
output.split("\n").each do |line|
  if line.strip != ""
    if line[0].match(/^default.*/) || line[0].match(/^[0-9]+.*/)
      pattern = /^([0-9a-z\-A-Z\.]+)\s+([0-9a-z\-A-Z\.]+).*\s(.*)$/
      target = line.gsub(pattern, '\1')
      gw = line.gsub(pattern, '\2')
      iface = line.gsub(pattern, '\3')
      routes[target] = {
        "gateway" => gw,
        "interface" => iface
      }
    end
  end
end
