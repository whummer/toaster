class myclass1 {
    file { '/tmp/test1':
        ensure => present,
        content => 'Test 1'
    }

    file { '/tmp/test2':
        ensure => present,
        content => 'Test 2'
    }
}

include myclass1
