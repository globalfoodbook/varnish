#!/bin/bash

set -e
set -x

cp /etc/varnish/default.vcl.original /etc/varnish/default.vcl

for name in BACKEND_PORT_5118_TCP_PORT BACKEND_PORT_5118_TCP_ADDR VARNISH_HOST
do
  eval value=\$$name
  sed -i "s|\${${name}}|${value}|g" /etc/varnish/default.vcl
done

# default="$(cat /etc/varnish/default.vcl.original)"
# echo $(eval echo \"$default\") > /etc/varnish/default.vcl
counter=0
until $(curl --output /dev/null --silent --head --fail http://$BACKEND_PORT_5118_TCP_ADDR:$BACKEND_PORT_5118_TCP_PORT); do
  counter=$((counter+1));
  if [ $counter -eq 90 ]; then break; fi;
  sleep 1;
done
# Start varnish and log
/etc/varnish/sbin/varnishd -f /etc/varnish/default.vcl -s malloc,100M -a 0.0.0.0:80
/etc/varnish/bin/varnishlog
