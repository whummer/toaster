#
# Default user is "disco" and recipe disco::default assumes that 
# this user already exists, hence the recipe fails by default. To 
# fix this, we can either:
# * create user/group 'disco' before the actual recipe runs.
# * tell the recipe to use the 'root' user.
# 

node.set["disco"]["user"] = "root"
node.set["disco"]["group"] = "root"

#user "disco" do
#  action :create
#end
#
#group "disco" do
#  action :create
#  members "disco"
#  system false
#  append false
#end
