# https://forge.puppetlabs.com/puppetlabs/apt

class { 'apt':
  always_apt_update    => false,
  apt_update_frequency => undef,
  disable_keys         => undef,
  proxy_host           => false,
  proxy_port           => '8080',
  purge_sources_list   => false,
  purge_sources_list_d => false,
  purge_preferences_d  => false,
  update_timeout       => undef,
  fancy_progress       => undef
}

apt::unattended_upgrades {
  origins             = $::apt::params::origins,
  blacklist           = [],
  update              = '1',
  download            = '1',
  upgrade             = '1',
  autoclean           = '7',
}

apt_key { 'puppetlabs':
  ensure => 'present',
  id     => '1054B7A24BD6EC30',
}

apt::hold { 'vim':
  version => '2:7.3.547-7',
}
