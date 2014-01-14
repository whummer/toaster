

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "packages"
packages Mash.new

`which dpkg`
has_dpkg = $? == 0
`which yum`
has_yum = $? == 0

if has_yum
  output = `yum list installed`
  output.split("\n").each do |line|
    if line.strip != "" && line[0]  != "*"
      parts = line.split(/\s+/)
      packages[parts[0]] = parts[1] if parts[0] && parts[1]
    end
  end
elsif has_dpkg
  output = `dpkg -l`
  output.split("\n").each do |line|
    if line.strip != "" && line[0]  != "*"
      parts = line.split(/\s+/)
      if parts.size >= 3 && parts[1] && parts[1] != "Name"&& parts[2]
        packages[parts[1]] = parts[2]
      end
    end
  end
end
