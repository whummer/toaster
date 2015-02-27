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

class myclass2 {
    include myclass1

    file { '/tmp/test3':
        ensure => present,
        content => 'Test 3'
    }
}

include myclass2

file { '/tmp/test4':
    ensure => present,
    content => 'Test 4',
    require => Class['myclass2']
}
