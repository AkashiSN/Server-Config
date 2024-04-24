# syntax = docker/dockerfile:1.4
FROM alpine AS build

ENV SSLH_VERSION="v2.1.1"

RUN <<EOT
apk add --no-cache \
    gcc \
    git \
    libconfig-dev \
    make \
    musl-dev \
    pcre2-dev \
    perl

git clone --recursive https://github.com/yrutschle/sslh.git -b ${SSLH_VERSION} --depth=1 /tmp/sslh
cd /tmp/sslh

./configure
make sslh-select
strip sslh-select
EOT

FROM alpine

COPY --from=build /tmp/sslh/sslh-select /usr/local/bin/sslh

RUN <<EOT
apk add --no-cache \
    libconfig \
    pcre2 \
    iptables \
    ip6tables \
    libcap

adduser -s '/bin/sh' -S -D sslh
setcap cap_net_bind_service,cap_net_raw+ep /usr/local/bin/sslh
EOT

COPY --from=build /tmp/sslh/container-entrypoint.sh /init
ENTRYPOINT [ "/init" ]

# required for updating iptables
USER root:root
