#!/bin/bash

# Make sure to start boot2docker before running this script
eval "$(docker-machine env default)"

/usr/local/bin/docker login

read -p "What version number or tag are you deploying? " tag

if [[ $tag ]]; then
  /usr/local/bin/docker build -t globalfoodbook/varnish:$tag .
  /usr/local/bin/docker push globalfoodbook/varnish:$tag

  /usr/local/bin/docker build -t globalfoodbook/varnish:latest .
  /usr/local/bin/docker push globalfoodbook/varnish:latest
else
  echo -e "Kindly provide a tag or version number"
fi
