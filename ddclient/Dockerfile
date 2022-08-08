# syntax=docker.io/docker/dockerfile:1.4.2-labs

FROM ubuntu:22.04

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive
ENV DDCLIENT_VERSION=3.10.0_2

COPY crond /usr/bin/crond

RUN <<EOT
apt-get update
apt-get install -y \
  automake \
  busybox-static \
  curl \
  dnsutils \
  gettext \
  iproute2 \
  make \
  perl \
  libdata-validate-ip-perl \
  libhttp-daemon-ssl-perl \
  libio-socket-inet6-perl \
  libio-socket-ssl-perl \
  libjson-perl \
  libplack-perl
apt-get clean

curl -sLo /tmp/ddclient-${DDCLIENT_VERSION}.tar.gz https://github.com/ddclient/ddclient/archive/refs/tags/v${DDCLIENT_VERSION}.tar.gz
tar xf /tmp/ddclient-${DDCLIENT_VERSION}.tar.gz -C /tmp

cd /tmp/ddclient-${DDCLIENT_VERSION}
./autogen
./configure \
    --prefix=/usr \
    --sysconfdir=/etc/ddclient \
    --localstatedir=/var
make
install -c ddclient /usr/bin
mkdir -p /etc/ddclient
mkdir -p /var/cache/ddclient

rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

mkdir -p /var/spool/cron/crontabs
echo "*/10 * * * *  /usr/bin/ddclient retry"> /var/spool/cron/crontabs/root
EOT
