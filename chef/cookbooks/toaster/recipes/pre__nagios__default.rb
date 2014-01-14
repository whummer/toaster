# nagios::default uses search(...) which is only available 
# with chef server. Cookbook chef-solo-search fixes this.
include_recipe "chef-solo-search::default"