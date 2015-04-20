FROM centos:7

RUN yum install -y make gcc gcc-c++ ruby ruby-devel wget curl strace tar hostname
RUN gem install --no-ri --no-rdoc thor rest-client

RUN wget https://get.docker.com/builds/Linux/x86_64/docker-latest -O /usr/bin/docker && chmod +x /usr/bin/docker

ENV PATH /opt/citac/bin:/opt/citac/bin/docker:$PATH