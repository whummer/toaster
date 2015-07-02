#!/bin/sh

test -e /var/citac/cache/00 || (chmod 0777 /var/citac/cache; squid3 -z)
squid3 -N
