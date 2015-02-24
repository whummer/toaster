FROM debian:wheezy

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y squid3

COPY squid.conf /etc/squid3/squid.conf
COPY run-squid.sh /opt/run-squid.sh

RUN chmod +x /opt/run-squid.sh
RUN mkdir -p /var/citac/cache && chmod 0777 /var/citac/cache

CMD /opt/run-squid.sh
