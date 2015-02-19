# https://forge.puppetlabs.com/jhoblitt/nsstools

nsstools::create { '/etc/dirsrv/slapd-ldap1':
  owner          => 'nobody',
  group          => 'nobody',
  mode           => '0660',
  password       => 'example',
  manage_certdir => false,
  enable_fips    => false,
}
