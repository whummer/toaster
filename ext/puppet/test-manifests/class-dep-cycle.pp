class myclass1 {
    file { '/tmp/test1':
        ensure => present,
        content => 'Test 1'
    }

    file { '/tmp/test2':
        ensure => present,
        content => 'Test 2',
        require => File['/tmp/test3']
    }
}

include myclass1

file { '/tmp/test3':
    ensure => present,
    content => 'Test 3',
    require => Class['myclass1']
}

