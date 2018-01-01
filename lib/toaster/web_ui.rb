
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

dir = File.join(File.dirname(__FILE__), "..", "..")
exec("cd \"#{dir}\" && bundle install && webapp/bin/rails server thin")
