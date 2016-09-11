FROM centos:7

# Required Packages

RUN yum install -y \
    wget curl tar hostname bzip2 net-tools \
    make gcc gcc-c++ \
    ruby ruby-devel \
 && gem install --no-ri --no-rdoc thor rest-client hashdiff \
 && curl -sSL https://get.docker.com/ | sh

# Strace 4.10 Installation (compilation from source)

RUN wget http://downloads.sourceforge.net/project/strace/strace/4.10/strace-4.10.tar.xz -O /tmp/strace-4.10.tar.xz \
 && tar -C /tmp -xf /tmp/strace-4.10.tar.xz \
 && cd /tmp/strace-4.10 && ./configure \
 && make -C /tmp/strace-4.10 \
 && make -C /tmp/strace-4.10 install \
 && rm -rf /tmp/strace-4.10 /tmp/strace-4.10.tar.xz

# Citac Installation

RUN mkdir -p /opt/citac
ADD citac.tar.gz /opt/citac

ENV PATH /opt/citac/bin:/opt/citac/bin/docker:$PATH
