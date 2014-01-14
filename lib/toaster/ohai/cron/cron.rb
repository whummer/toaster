

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

provides "cron"
cron Array.new

# build list of cron jobs
out = `crontab -l`

# crontab syntax:
# m h  dom mon dow   command

out.split("\n").each do |line|
  # check if line is a comment
  if !line.match(/^\s*#/)
    # extract values
    line.scan(/\s*([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(.*)/) {
      |m,h,dom,mon,dow,cmd|
      cron << {
        "m" => m,
        "h" => h,
        "dom" => dom,
        "mon" => mon,
        "dow" => dow,
        "command" => cmd
      }
    }
  end
end
