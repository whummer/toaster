FROM debian:wheezy

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy ca-certificates ruby ruby-dev wget curl build-essential

RUN wget http://downloads.sourceforge.net/project/strace/strace/4.10/strace-4.10.tar.xz -O /tmp/strace-4.10.tar.xz \
 && cd /tmp             && tar xf strace-4.10.tar.xz \
 && cd /tmp/strace-4.10 && ./configure && make && make install \
 && cd /tmp             && rm -rf strace*

RUN gem install --no-ri --no-rdoc thor rest-client

RUN curl -sSL https://get.docker.com/ | sh

ENV PATH /opt/citac/bin:/opt/citac/bin/docker:$PATH