# https://forge.puppetlabs.com/puppetlabs/inifile

ini_setting { "sample setting":
  ensure  => present,
  path    => '/tmp/foo.ini',
  section => 'foo',
  setting => 'foosetting',
  value   => 'FOO!',
}

JAVA_ARGS="-Xmx192m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/pe-puppetdb/puppetdb-oom.hprof "

ini_subsetting {'sample subsetting':
  ensure  => present,
  section => '',
  key_val_separator => '=',
  path => '/etc/default/pe-puppetdb',
  setting => 'JAVA_ARGS',
  subsetting => '-Xmx',
  value   => '512m',
}
