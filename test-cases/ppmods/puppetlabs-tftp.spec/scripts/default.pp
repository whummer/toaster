# https://forge.puppetlabs.com/puppetlabs/tftp

package { 'procps':
  before => Class['tftp']
}

class { 'tftp':
  directory => '/opt/tftp',
  address   => $::ipaddress,
  options   => '--ipv6 --timeout 60',
}
