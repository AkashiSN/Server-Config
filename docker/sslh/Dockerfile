# syntax = docker/dockerfile:1.4
FROM ubuntu:22.04 AS build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    SSLH_VERSION="v2.1.1"

RUN <<EOT
apt-get update
apt-get install -y \
  gcc \
  git \
  libbsd-dev \
  libcap-dev \
  libcap-dev \
  libconfig-dev \
  libpcre2-dev \
  libsystemd-dev \
  libwrap0-dev \
  make \
  perl

git clone --recursive https://github.com/yrutschle/sslh.git -b ${SSLH_VERSION} --depth=1 /tmp/sslh
cd /tmp/sslh

./configure
make USELIBWRAP=1 USELIBCAP=1 USESYSTEMD=1 USELIBBSD=1 sslh-select
strip sslh-select
EOT

FROM ubuntu:22.04

COPY --from=build /tmp/sslh/sslh-select /usr/local/bin/sslh
ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  iptables \
  libbsd0 \
  libcap2-bin \
  libconfig9 \
  libwrap0
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

useradd --shell '/bin/sh' --system --create-home sslh
setcap cap_net_bind_service,cap_net_raw+ep /usr/local/bin/sslh
EOT

COPY --from=build /tmp/sslh/container-entrypoint.sh /init
ENTRYPOINT [ "/init" ]

# required for updating iptables
USER root:root
