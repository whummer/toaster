#
# bug fix for virtualbox::default recipe, which calls a 
# resource "add Oracle key" that does not exist..
#

template "/etc/apt/sources.list.d/oracle-virtualbox.list" do
  source "oracle-virtualbox.list.erb"
  mode 0644
  # original:
  #notifies :run, resources(:bash => "add Oracle key"), :immediately
  # fixed (removed)
end
