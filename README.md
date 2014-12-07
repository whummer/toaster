# ToASTER

Automated testing of Infrastructure as Code automation scripts (e.g., Chef).

(ToASTER is an acronym for "Testing of Automation Scripts via Twisted Execution Runs")

## Building and Installing

* Important note: We highly recommend to install ToASTER only on dedicated machines,
  e.g., a clean virtual machine from Amazon EC2. Do not install toaster on any
  production servers or your own development machine! The reasons are twofold: first, 
  toaster requires a high amount of disk space for creating LXC containers, storing 
  test data etc; second, toaster relies on a comprehensive third-party software stack
  (docker.io, LXC, Squid, MySQL, Ruby, Ruby gems, etc), which might interfere with
  and pollute the working environment of production machines.

* Target platform: Ubuntu 13.04

```
# become root user
sudo su -

# prerequisites:
apt-get -y install wget make bzip2 curl patch screen libgdbm-dev libyaml-dev libxml2-dev libxslt-dev libmysqlclient-dev libsqlite3-dev g++
gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
curl -L https://get.rvm.io | bash -s stable --ruby
# (OR: install stable ruby versions from repo: apt-get install -y ruby ruby-dev)
source /usr/local/rvm/scripts/rvm

# install toaster gem:
gem build cloud-toaster.gemspec
gem install --no-ri --no-rdoc cloud-toaster-*version*.gem

# (OR: install directly using rubygems.org: gem install cloud-toaster)

# toaster setup:
toaster setup					# (setup testing host / utility host. Enter 192.168.100.2 as "db.host" parameter)
toaster proto ubuntu1 ubuntu	# (initialize prototype container)
```

The code listing above illustrates the single-node installation. For multiple testing hosts,
set the db.host configuration to the public IP/hostname of a central MySQL DB server to be 
shared among all hosts.

## User Commands

```
toaster web -d 					# (run the Web UI in a screen session in the background; web port 8080)
toaster agent 					# (start test agent in the background; web port 8385)
toaster spawn lxc1 ubuntu1		# (create container)
toaster clean					# (clean containers)
```

## License

ToASTER is published under the Apache License version 2.0. See LICENSE file for details.
