schedule { 'everyday':
  period => daily,
  range  => "2-4"
}

exec { "/usr/bin/apt-get update":
  schedule => 'everyday'
}

exec { "/bin/echo Hi":
  schedule => 'hourly'
}
