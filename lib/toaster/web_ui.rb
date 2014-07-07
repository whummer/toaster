
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

dir = File.join(File.dirname(__FILE__), "..", "..", "webapp")
exec("cd \"#{dir}\" && bundle install && rails server thin")
