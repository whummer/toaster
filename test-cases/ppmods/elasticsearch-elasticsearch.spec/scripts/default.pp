# https://forge.puppetlabs.com/elasticsearch/elasticsearch

class { 'elasticsearch':
  version => '1.4.2'
}

elasticsearch::instance { 'es-01': }
