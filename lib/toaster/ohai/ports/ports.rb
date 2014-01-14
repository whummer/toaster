

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "ports"
ports Mash.new
output = `nmap localhost | grep -e "[0-9][0-9]*\\/" 2>&1`
# build list of ports
output.split("\n").each do |line|
  if line.include?("/")
    port = line.split(" ")[0].split("/")[0].strip
    type = line.split(" ")[0].split("/")[1].strip
    status = line.split(" ")[1].strip
    service = line.split(" ")[2].strip

    ports[port] = [] if !ports[port]
    ports[port].push({"type" => type, "status" => status})
  end
end
