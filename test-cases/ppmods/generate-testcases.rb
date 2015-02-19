#!/usr/bin/env ruby

oss = ['debian', 'ubuntu', 'centos']
limit = 50

blacklist = [
  'fiddyspence-sysctl', # modifies Linux kernel parameters
  'garethr-docker', # installs docker
  'maestrodev-maven', # requires Maven installed
  'puppetlabs-stdlib', # is a support module
  'thias-sysctl' # modifies Linux kernel parameters
]

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

require 'set'

modules = Set.new

oss.each do |os|
  puts "Searching for the #{limit} most downloaded Puppet modules for operating system #{os}..."
  output = `citac puppet forge search --os #{os} --limit #{limit} --quiet`

  count_before = modules.size

  output.each_line do |line|
    module_name = line.strip
    modules << module_name unless blacklist.include? module_name
  end

  count_after = modules.size
  puts "#{count_after - count_before} new modules added."
end

puts "#{modules.size} modules found."

cl = modules.size.to_s.length

modules.each_with_index do |module_name, i|
  index = (i + 1).to_s.rjust cl
  prefix = "(#{index}/#{modules.size})"

  if Dir.exist? "#{module_name}.spec"
    puts "#{prefix} Skipping #{module_name} because test case already exists."
    next
  end

  puts "#{prefix} Generating test case for #{module_name}..."
  output = `citac puppet spec #{module_name} 2>&1`

  unless $?.exitstatus == 0
    STDERR.puts "#{prefix} Failed to generate test case for #{module_name}: #{output}"
  end
end

puts 'Done.'