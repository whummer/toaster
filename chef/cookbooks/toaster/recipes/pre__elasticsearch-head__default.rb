#
# pre-processing customizations for recipe elasticsearch-head::default
#

# apparently, Squid proxy by default cannot cache this https file from github: 
# original (defined in attributes/default.rb):
# default[:elastichead][:src_mirror] = 
#  "https://github.com/mobz/elasticsearch-head/tarball/#{node[:elastichead][:src_branch]}"
# fixed (changed from https to http):
node.set[:elastichead][:src_mirror] =
  "http://github.com/mobz/elasticsearch-head/tarball/#{node[:elastichead][:src_branch]}"
