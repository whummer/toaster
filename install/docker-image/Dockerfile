FROM ubuntu:trusty

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy ca-certificates git-core wget curl build-essential ruby ruby-dev graphviz

RUN gem install --no-ri --no-rdoc thor rest-client hashdiff

RUN git clone https://github.com/citac/citac.git /opt/citac

ENV PATH /opt/citac/bin:$PATH