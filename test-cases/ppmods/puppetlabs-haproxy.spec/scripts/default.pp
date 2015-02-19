# https://forge.puppetlabs.com/puppetlabs/haproxy

class { 'haproxy': }
  haproxy::listen { 'puppet00':
    collect_exported => false,
    ipaddress        => $::ipaddress,
    ports            => '8140',
  }
  haproxy::balancermember { 'master00':
    listening_service => 'puppet00',
    server_names      => 'master00.example.com',
    ipaddresses       => '10.0.0.10',
    ports             => '8140',
    options           => 'check',
  }
  haproxy::balancermember { 'master01':
    listening_service => 'puppet00',
    server_names      => 'master01.example.com',
    ipaddresses       => '10.0.0.11',
    ports             => '8140',
    options           => 'check',
  }
