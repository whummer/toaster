FROM ubuntu:trusty

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy ca-certificates make g++ ruby ruby-dev wget curl strace

RUN gem install --no-ri --no-rdoc thor rest-client

RUN curl -sSL https://get.docker.com/ | sh

ENV PATH /opt/citac/bin:/opt/citac/bin/docker:$PATH