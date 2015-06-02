FROM citac_environments/base:debian-7

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy pkg-config libaugeas-dev \
 && gem install --no-ri --no-rdoc ruby-augeas

RUN gem install --no-ri --no-rdoc puppet --version 3.7.5
