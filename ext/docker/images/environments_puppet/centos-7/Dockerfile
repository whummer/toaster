FROM citac/environments:base_centos-7

RUN yum install -y augeas-devel libxml2-devel libxslt-devel \
 && gem install --no-ri --no-rdoc nokogiri -- --use-system-libraries \
 && gem install --no-ri --no-rdoc ruby-augeas

RUN gem install --no-ri --no-rdoc puppet --version 3.7.5
