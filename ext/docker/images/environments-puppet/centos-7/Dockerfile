FROM citac_environments/base:centos-7

RUN yum install -y augeas-devel \
 && gem install --no-ri --no-rdoc ruby-augeas

RUN gem install --no-ri --no-rdoc nokogiri

RUN gem install --no-ri --no-rdoc puppet --version 3.7.5
