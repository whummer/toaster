
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'rubygems'
require 'toaster/chef/resource_inspector'
require 'toaster/model/task'

include Toaster

describe ResourceInspector, "::get_accessed_parameters" do

  code1 = <<-EOC
  execute "a2enmod \#{params[:name]}" do
    command "/usr/sbin/a2enmod \#{params[:name]}"
    notifies :restart, resources(:service => "apache2")
    not_if do (::File.symlink?("\#{node['apache']['dir']}/mods-enabled/\#{params[:name]}.load") and
          ((::File.exists?("\#{node['apache']['dir']}/mods-available/\#{params[:name]}.conf"))?
            (::File.symlink?("\#{node['apache']['dir']}/mods-enabled/\#{params[:name]}.conf")):(true)))
    end
  end
  EOC

  task1 = Task.new(nil, nil, code1)

  it "returns only one attribute if multiple occurrences" do
    params = ResourceInspector.get_accessed_parameters(code1)
    params.size.should eq(1)
    params = ResourceInspector.get_accessed_parameters(task1)
    params.size.should eq(1)
  end
  it "parses attributes correctly" do
    params = ResourceInspector.get_accessed_parameters(code1)
    params = params.collect { |p| p.key }
    params.should eq(["'apache'.'dir'"])
    params = ResourceInspector.get_accessed_parameters(task1)
    params = params.collect { |p| p.key }
    params.should eq(["'apache'.'dir'"])
  end
end
