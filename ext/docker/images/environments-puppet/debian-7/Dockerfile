FROM citac_environments/base:debian-7

RUN wget https://apt.puppetlabs.com/puppetlabs-release-wheezy.deb 2>&1 \
 && dpkg -i puppetlabs-release-wheezy.deb \
 && rm -f puppetlabs-release-wheezy.deb

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy puppet-common

RUN sed -i -e "/^templatedir=/ d" /etc/puppet/puppet.conf