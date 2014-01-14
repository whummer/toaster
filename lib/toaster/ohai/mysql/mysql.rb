

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "mysql"
mysql Mash.new

# we expect return code "1" if the following command fails because 
# the root password has already been set and hence access is denied
out = `mysql -u root -e 'show databases;' 2>&1`
mysql["root_password_set"] = $? == 1

if File.exist?("/etc/mysql/my.cnf")

  cnf = File.read("/etc/mysql/my.cnf").gsub("\n", " : ")
  datadir = cnf.gsub(/.*datadir\s*=\s*([^:]+).*/, '\1').strip

  Dir.foreach(datadir) do |file|
    if file != "." && file != ".."
      path = file[0] == "/" ? file : File.join(datadir, file)
      if File.directory?(path)
        name = path.include?("/") ? path[path.rindex("/")+1..-1] : path
        mysql["databases"] = [] if !mysql["databases"]
        mysql["databases"] << name
      end
    end
  end

end
