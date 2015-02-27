class ntp {

  package { 'ntp':
    ensure => installed,
  }

  service { 'ntp':
    ensure  => running,
    enable  => true,
    require => Package['ntp'],
  }

  file { '/etc/ntp.conf':
    content => '123',
    notify => Service['ntp'],
  }
}

node default {
  include ntp
}
