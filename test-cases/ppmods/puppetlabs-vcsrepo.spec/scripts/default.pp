# https://forge.puppetlabs.com/puppetlabs/vcsrepo

vcsrepo { "/path/to/repo":
  ensure   => present,
  provider => git,
  source   => "https://github.com/oliverhanappi/roclobak.git",
}
