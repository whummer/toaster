class { 'postgresql::globals':
    version             => '9.3',
}

class { 'postgresql::server': }

Class['postgresql::globals'] -> Class['postgresql::server']
