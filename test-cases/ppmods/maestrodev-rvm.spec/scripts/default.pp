# https://forge.puppetlabs.com/maestrodev/rvm

include rvm

rvm_system_ruby {
  'ruby-1.9':
    ensure      => 'present',
    default_use => true,
    build_opts  => ['--binary'];
  'ruby-2.0':
    ensure      => 'present',
    default_use => false;
}
