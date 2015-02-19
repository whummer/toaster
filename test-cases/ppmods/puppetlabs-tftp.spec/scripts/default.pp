# https://forge.puppetlabs.com/puppetlabs/tftp

class tftp {
  directory => '/opt/tftp',
  address   => $::ipaddress,
  options   => '--ipv6 --timeout 60',
}
