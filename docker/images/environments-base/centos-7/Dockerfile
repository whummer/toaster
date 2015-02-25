FROM centos:7

RUN yum install -y ruby wget curl strace tar
RUN gem install --no-ri --no-rdoc thor rest-client

ENV PATH /opt/citac/bin:$PATH