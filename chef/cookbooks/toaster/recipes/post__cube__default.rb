#
# Here, we only want to reduce the verbosity of "warning" 
# outputs during compilation of node.js.
#

bash "compile node.js" do
  cwd "/usr/local/src/node-v#{node['nodejs']['version']}"
  code <<-EOH
    # original:
    #./configure --prefix=#{node['nodejs']['dir']} && \
    #make
    # fixed:
    ./configure --prefix=#{node['nodejs']['dir']} && \
    make | grep -v "warning:"
  EOH
  creates "/usr/local/src/node-v#{node['nodejs']['version']}/node"
end

execute "nodejs make install" do
  # original:
  #command "make install"
  # fixed:
  command "make install | grep -v 'warning:'"
  cwd "/usr/local/src/node-v#{node['nodejs']['version']}"
  not_if {File.exists?("#{node['nodejs']['dir']}/bin/node") && `#{node['nodejs']['dir']}/bin/node --version`.chomp == "v#{node['nodejs']['version']}" }
end