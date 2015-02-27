# https://forge.puppetlabs.com/ajcrowe/supervisord

# Install supervisord and install pip if not available.

class prerequisites {
  package { 'curl': }
  package { 'python': }
}

class { 'prerequisites':
  before => [Class['supervisord'], Class['supervisord::pip']]
}

class { 'supervisord':
  install_pip => true
}
