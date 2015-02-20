# https://forge.puppetlabs.com/puppetlabs/inifile

ini_setting { "sample setting":
  ensure  => present,
  path    => '/tmp/foo.ini',
  section => 'foo',
  setting => 'foosetting',
  value   => 'FOO!',
}

ini_subsetting {'sample subsetting':
  ensure  => present,
  section => '',
  key_val_separator => '=',
  path => '/etc/default/pe-puppetdb',
  setting => 'JAVA_ARGS',
  subsetting => '-Xmx',
  value   => '512m',
}
