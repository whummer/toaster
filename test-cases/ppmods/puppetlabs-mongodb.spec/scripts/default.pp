# https://forge.puppetlabs.com/puppetlabs/mongodb

include '::mongodb::server'

class {'::mongodb::client':}
