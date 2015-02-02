FROM ubuntu:trusty

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates wget

RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb 2>&1 \
 && dpkg -i puppetlabs-release-trusty.deb \
 && rm -f puppetlabs-release-trusty.deb

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y puppet-common

ENV PATH /opt/citac/bin:$PATH