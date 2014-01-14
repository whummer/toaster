#
# Cookbook Name:: php
# Recipe:: authorize_key
#
# Author:: Waldemar Hummer
# 

script "authorize_key" do
  interpreter "bash"
  user "root"
  cwd "/root"
  ENV['SSH_PUB_KEY'] = node['ssh']['public_key']
  code <<-EOH
  mkdir -p $HOME/.ssh
  existing=`cat $HOME/.ssh/authorized_keys | grep "$SSH_PUB_KEY"`
  if [ "$existing" == "" ]; then
    echo "$SSH_PUB_KEY" >> $HOME/.ssh/authorized_keys
  fi
  EOH
end
