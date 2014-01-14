#
# At the time of writing, the drupal::default recipe fails because 
# server_aliases has to be an array (and not a string, as below), 
# otherwise the Apache2 config file templating fails.
# This post-processing recipe should fix the bug.
#

web_app "drupal" do
  template "drupal.conf.erb"
  docroot node['drupal']['dir']
  server_name server_fqdn
  # original
  #server_aliases node['fqdn']
  # fixed
  server_aliases [node['fqdn']]
end
