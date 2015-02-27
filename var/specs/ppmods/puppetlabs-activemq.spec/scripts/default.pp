# https://forge.puppetlabs.com/puppetlabs/activemq

node default {
  notify { 'alpha': }
  ->
  class  { 'java':
    distribution => 'jdk',
    version      => 'latest',
  }
  ->
  class  { 'activemq': }
  ->
  notify { 'omega': }
}
