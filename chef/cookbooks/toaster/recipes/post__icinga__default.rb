# Avoid EnclosingDirectoryDoesNotExist exception.
# --> add "recursive=true" parameter
directory "#{node['icinga']['config_dir']}" do
  owner node['icinga']['user']
  group node['icinga']['group']
  mode "0755"
  # new:
  recursive true
end