# https://forge.puppetlabs.com/maestrodev/wget

include wget

wget::fetch { "download Google's index":
  source      => 'http://www.google.com/index.html',
  destination => '/tmp/index.html',
  timeout     => 0,
  verbose     => false,
}
