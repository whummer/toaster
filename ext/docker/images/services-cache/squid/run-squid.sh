#!/bin/sh

test -e /var/citac/cache/swap.state || squid3 -z
squid3 -N
