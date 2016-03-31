# An Varnish running inside docker.

A Docker container for setting up Vanish. This server can respond to requests from any client browser with cached content after the initial request has been successful. This container best suites development purposes.

This is a sample Varnish docker container used to test Wordpress installation on [http://globalfoodbook.com](http://globalfoodbook.com)


To build this varnish server run the following command:

```bash
$ docker pull globalfoodbook/varnish
```

This will run on a default port of 80.

To run the server and expose it on port 80 of the host machine, run the following command:

```bash
$ docker run --name=varnish --link=gfb:backend -e VARNISH_HOST=globalfoodbook.com  --detach=true --publish=80:80 --tty=true varnish
```

# NB:

Take note the linking above --link=gfb:backend.. 'backend' is compulsory as it is being referenced within (Environment variables).

## Before pushing to docker hub

## Login

```bash
$ docker login
```

## Build

```bash
$ cd /to/docker/directory/path/
$ docker build -t <username>/<repo>:latest .
```

## Push to docker hub

```bash
$ docker push <username>/<repo>:latest
```


IP=`docker inspect varnish | grep -w "IPAddress" | awk '{ print $2 }' | head -n 1 | cut -d "," -f1 | sed "s/\"//g"`
HOST_IP=`/sbin/ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

DOCKER_HOST_IP=`awk 'NR==1 {print $1}' /etc/hosts` # from inside a docker container
