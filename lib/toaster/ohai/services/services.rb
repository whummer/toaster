

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "services"
services Mash.new
output = `service --status-all 2>&1`
# build up map of services
output.split("\n").each do |line|
  if line.include?("]")
    id = line.split("]")[1].strip
    status = line.split("]")[0].sub("[","").strip

    # try to determine some missing statuses..
    if status == "?"
      if id == "mysql"
        out = `echo 'select 1' | mysql 2>&1`
        status = "+"
        if out.include?("ERROR 2002") || out.include?("Can't connect")
          status = "-"
        end
      elsif id == "mongodb"
        out = `mongodb 2>&1`
        status = "+"
        if out.include?("couldn't connect") || out.include?("connect failed")
          status = "-"
        end
      elsif id == "activemq"
        out = `service activemq status 2>&1`
        if out.include?("not running")
          status = "-"
        elsif out.include?("is running")
          status = "+"
        end
      end
    end
    
    services[id] = status
  end
end
