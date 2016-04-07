# Start with a base Ubuntu 14:04 image
FROM ubuntu:trusty

MAINTAINER Ikenna N. Okpala <me@ikennaokpala.com>

USER root

# set HOME so 'npm install' and 'bower install' don't write to /
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.en
ENV LC_ALL en_US.UTF-8
ENV VARNISH_VERSION 4.1.2
ENV VARNISH_BACKEND_PORT 5118
ENV VARNISH_BACKEND_IP 127.0.0.1
ENV VARNISH_HOST localhost
ENV VARNISH_PORT 80

# Add all base dependencies
RUN apt-get update -y
RUN apt-get install -y build-essential checkinstall language-pack-en-base
RUN apt-get install -y vim curl wget libcurl4-openssl-dev mime-support automake libtool python-docutils libreadline-dev
RUN apt-get install -y pkg-config libssl-dev libgmp-dev zlib1g-dev libxslt-dev libxml2-dev libpcre3 libpcre3-dev freetds-dev git-core libcurl4-openssl-dev mime-support automake libtool python-docutils libreadline-dev
RUN apt-get install -y pkg-config libssl-dev
RUN apt-get install -y libncurses-dev

RUN apt-get install -y apt-transport-https
# RUN curl https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
# RUN echo "deb https://repo.varnish-cache.org/ubuntu/ trusty varnish-${VARNISH_VERSION}" >> /etc/apt/sources.list.d/varnish-cache.list
# RUN apt-get update -y
# RUN apt-get install -y varnish

RUN /bin/bash -l -c "wget https://repo.varnish-cache.org/source/varnish-${VARNISH_VERSION}.tar.gz"
RUN  /bin/bash -l -c "tar xvzf varnish-${VARNISH_VERSION}.tar.gz"
RUN cd varnish-${VARNISH_VERSION} && ./autogen.sh && ./configure --prefix=/etc/varnish && make && make install
RUN /bin/bash -l -c "rm -rf varnish-${VARNISH_VERSION}*"

# RUN mv /etc/varnish/default.vcl /etc/varnish/default.vcl.default
RUN mkdir -p /etc/varnish/inc

ADD templates/default.vcl /etc/varnish/default.vcl.original
ADD templates/bigfiles.vcl /etc/varnish/inc/bigfiles.vcl
ADD templates/purge.vcl /etc/varnish/inc/purge.vcl
ADD templates/static.vcl /etc/varnish/inc/static.vcl
ADD templates/xforward.vcl /etc/varnish/inc/xforward.vcl
ADD templates/bad_bot_detection.vcl /etc/varnish/inc/bad_bot_detection.vcl
ADD templates/start.sh /etc/varnish/start.sh
RUN chmod +x /etc/varnish/start.sh

RUN echo "Europe/London" | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get -y install zsh
RUN if [ ! -f /root/.oh-my-zsh/ ]; then git clone git://github.com/robbyrussell/oh-my-zsh.git /root/.oh-my-zsh;fi
RUN cp /root/.oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc
RUN chsh -s $(which zsh) root && zsh && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /root/.zshrc

ADD templates/start.sh /etc/start.sh
RUN chmod +x /etc/start.sh

# VOLUMES ["/var/lib/varnish", "/etc/varnish"]

EXPOSE 80
EXPOSE 443

# Setup the entrypoint
ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/etc/start.sh"]
