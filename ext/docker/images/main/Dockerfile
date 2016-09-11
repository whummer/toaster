FROM citac/environments:base_ubuntu-14.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qy graphviz

RUN touch /opt/citac/incontainer