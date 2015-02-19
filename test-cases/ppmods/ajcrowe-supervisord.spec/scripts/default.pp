# https://forge.puppetlabs.com/ajcrowe/supervisord

# Install supervisord and install pip if not available.

class { 'supervisord':
  install_pip => true,
}
