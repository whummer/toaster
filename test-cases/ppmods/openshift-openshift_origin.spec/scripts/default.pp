# https://forge.puppetlabs.com/openshift/openshift_origin
# https://github.com/openshift/puppet-openshift_origin

class { 'openshift_origin' :
  domain                        => 'example.com',
  node_unmanaged_users          => ['root'],
  development_mode              => true,
  conf_node_external_eth_dev    => 'eth0',
  install_method                => 'yum',
  register_host_with_nameserver => true,
  broker_auth_plugin            => 'remote-user',
  broker_dns_plugin             => 'nsupdate',
  bind_krb_principal            => $hostname,
  bind_krb_keytab               => '/etc/dns.keytab'
  broker_krb_keytab             => '/etc/http.keytab',
  broker_krb_auth_realms        => 'EXAMPLE.COM',
  broker_krb_service_name       => $hostname,
}
