# https://forge.puppetlabs.com/maestrodev/rvm

class prerequisites {
    exec { '/usr/bin/gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3': }
}

class { 'prerequisites':
  before => Class['rvm']
}

class { 'rvm': }
