# https://forge.puppetlabs.com/puppetlabs/passenger

package{ 'ruby1.9.1-dev':
  before => Class['passenger']
}

class {'passenger': }

