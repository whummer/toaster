# recipe netkernel::default uses an illegal statement which we fix here:
# "source defaults.erb" (string should be under apostrophe)
class MyFoo
  def erb
    "defaults.erb"
  end
end
class ::Chef
  class Node
    def defaults
      return MyFoo.new
    end
  end
end
service "apache" do
  supports :restart => true, :reload => true
  action :nothing
end
directory "/opt/netkernel/bin/" do
  action :create
  owner "root"
  group "root"
  recursive true
end
