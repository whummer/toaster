# https://forge.puppetlabs.com/pdxcat/collectd

include collectd

class { 'collectd::plugin::cpu':
}

class { 'collectd::plugin::cpufreq':
}

class { 'collectd::plugin::disk':
  disks          => ['/^dm/'],
  ignoreselected => true
}
