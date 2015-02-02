FROM centos:7

RUN rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm \
 && yum install -y puppet

ENV PATH /opt/citac/bin:$PATH