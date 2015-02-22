# https://forge.puppetlabs.com/elasticsearch/logstash

class { 'logstash':
  manage_repo  => true,
  repo_version => '1.3'
}
