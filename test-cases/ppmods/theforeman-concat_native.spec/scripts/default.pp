# https://forge.puppetlabs.com/theforeman/concat_native

concat_build { "identifier":
  order => ['*.tmp'],
  target => '/tmp/test'
}

concat_fragment { "identifier+01.tmp":
  content => "Some random stuff"
}

concat_fragment { "identifier+02.tmp":
  content => "Some other random stuff"
}
