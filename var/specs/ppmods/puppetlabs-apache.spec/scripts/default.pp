# https://forge.puppetlabs.com/puppetlabs/apache

class { 'apache':  }

apache::vhost { 'first.example.com':
  port    => '80',
  docroot => '/var/www/first',
}
