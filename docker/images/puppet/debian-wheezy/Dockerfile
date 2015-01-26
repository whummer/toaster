FROM debian:wheezy

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates wget

RUN wget https://apt.puppetlabs.com/puppetlabs-release-wheezy.deb 2>&1 \
 && dpkg -i puppetlabs-release-wheezy.deb \
 && rm -f puppetlabs-release-wheezy.deb

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y puppet-common
