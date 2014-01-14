# Pre-processing tasks for recipe solr::default

# solr::default calls openldap::default, which tries 
# to access node['domain'].length, but node['domain'] is 
# nil (not automatically set by our Chef installation).
node.set['domain'] = ''