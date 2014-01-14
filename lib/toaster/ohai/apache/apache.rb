

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "apache"
apache Mash.new

apache["loaded_modules"] = []
apache["mods-enabled"] = []
apache["sites-available"] = []
apache["sites-enabled"] = []

# build list of Apache modules
modules = `/usr/sbin/apachectl -t -D DUMP_MODULES 2> /dev/null`
modules.split("\n").each do |line|
  if line.match(/^\s*[0-9a-zA-Z_]+\s+\([a-z]+\)$/)
    mod = line.sub(/^\s*([0-9a-zA-Z_]+)\s+\([a-z]+\)$/, '\1')
    if mod
      apache["loaded_modules"] << mod
    end
  end
end

# build list of entries in /etc/apache2/mods-enabled/
Dir["/etc/apache2/mods-enabled/*"].each do |entry|
  mod = entry.sub(/.*\/([a-z0-9A-Z_\-]*)\.((load)|(conf)).*/, '\1')
  if !mod.strip.empty? && !apache["mods-enabled"].include?(mod)
    apache["mods-enabled"] << mod
  end
end

# build list of entries in /etc/apache2/sites-available
Dir["/etc/apache2/sites-available/*"].each do |entry|
  site = entry.strip
  if !site.empty? && !apache["sites-available"].include?(site)
    apache["sites-available"] << site
  end
end

# build list of entries in /etc/apache2/sites-enabled
Dir["/etc/apache2/sites-enabled/*"].each do |entry|
  site = entry.strip
  if !site.empty? && !apache["sites-enabled"].include?(site)
    apache["sites-enabled"] << site
  end
end
