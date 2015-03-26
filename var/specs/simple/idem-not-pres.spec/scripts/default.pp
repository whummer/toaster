file { '/tmp/test.txt':
    ensure => present,
    content => 'Test 1'
}

exec { '/bin/sh -c "echo Test 2 >> /tmp/test.txt"':
    require => File['/tmp/test.txt']
}
