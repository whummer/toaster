# https://forge.puppetlabs.com/elasticsearch/elasticsearch

class prerequisites {
    package { 'openjdk-7-jre': }
}

class { 'prerequisites':
  before => Class['elasticsearch']
}

class { 'elasticsearch':
  manage_repo  => true,
  repo_version => '1.4',
  version => '1.4.2'
}

elasticsearch::instance { 'es-01': }
