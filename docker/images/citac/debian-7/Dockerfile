FROM debian:wheezy

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates ruby

RUN gem install --no-ri --no-rdoc thor rest_client

ENV PATH /opt/citac/bin:$PATH