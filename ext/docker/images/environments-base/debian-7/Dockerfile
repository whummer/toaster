FROM debian:wheezy

# Required Packages

COPY sources.list /etc/apt/sources.list

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy ca-certificates wget curl build-essential net-tools lsb-release

# Strace 4.10 Installation (compilation from source)

RUN wget http://downloads.sourceforge.net/project/strace/strace/4.10/strace-4.10.tar.xz -O /tmp/strace-4.10.tar.xz \
 && tar -C /tmp -xf /tmp/strace-4.10.tar.xz \
 && cd /tmp/strace-4.10 && ./configure \
 && make -C /tmp/strace-4.10 \
 && make -C /tmp/strace-4.10 install \
 && rm -rf /tmp/strace-4.10 /tmp/strace-4.10.tar.xz

# Ruby 2.1.6 Installation with ruby-install

RUN wget https://github.com/postmodern/ruby-install/archive/v0.5.0.tar.gz -O /tmp/ruby-install-0.5.0.tar.gz \
 && tar -C /tmp -xf /tmp/ruby-install-0.5.0.tar.gz \
 && make -C /tmp/ruby-install-0.5.0 install \
 && rm -rf /tmp/ruby-install-0.5.0 /tmp/ruby-install-0.5.0.tar.gz \
 && ruby-install --system ruby 2.1.6

RUN gem install --no-ri --no-rdoc thor rest-client hashdiff
RUN gem install --no-ri --no-rdoc ohai --version 8.3.0

# Path Settings

ENV PATH /opt/citac/bin:/opt/citac/bin/docker:$PATH
