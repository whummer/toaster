# https://forge.puppetlabs.com/puppetlabs/java_ks

java_ks { 'puppetca:truststore':
  ensure       => latest,
  certificate  => '/etc/puppet/ssl/certs/ca.pem',
  target       => '/etc/activemq/broker.ts',
  password     => 'puppet',
  trustcacerts => true,
}

java_ks { 'puppetca:keystore':
  ensure       => latest,
  certificate  => '/etc/puppet/ssl/certs/ca.pem',
  target       => '/etc/activemq/broker.ks',
  password     => 'puppet',
  trustcacerts => true,
}

java_ks { 'broker.example.com:/etc/activemq/broker.ks':
  ensure      => latest,
  certificate => '/etc/puppet/ssl/certs/broker.example.com.pe-internal-broker.pem',
  private_key => '/etc/puppet/ssl/private_keys/broker.example.com.pe-internal-broker.pem',
  password    => 'puppet',
}
