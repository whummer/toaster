# https://forge.puppetlabs.com/sensu/sensu

class { 'sensu':
    rabbitmq_password => 'correct-horse-battery-staple',
    server            => true,
    api               => true,
    plugins           => [
      'puppet:///data/sensu/plugins/ntp.rb',
      'puppet:///data/sensu/plugins/postfix.rb'
    ]
  }
