# https://forge.puppetlabs.com/jhoblitt/nsstools

file { '/etc/dirsrv':
  ensure => 'directory',
  before => Nsstools::Create['/etc/dirsrv/slapd-ldap1']
}

nsstools::create { '/etc/dirsrv/slapd-ldap1':
  owner          => 'nobody',
  group          => 'nobody',
  mode           => '0660',
  password       => 'example',
  manage_certdir => true,
  enable_fips    => false,
}
