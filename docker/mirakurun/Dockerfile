# syntax = docker/dockerfile:1.4
ARG MIRAKURUN_VERSION=3.9.0-rc.2
FROM chinachu/mirakurun:${MIRAKURUN_VERSION} AS mirakurun-image
FROM ghcr.io/akashisn/libarib25 AS libarib25-image
FROM ghcr.io/akashisn/v4l-utils AS v4l-utils-image

FROM node:16.14.0-buster-slim

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV GCONV_PATH=/usr/local/lib/gconv
WORKDIR /app

COPY --from=mirakurun-image /app /app
COPY --from=libarib25-image / /
COPY --from=v4l-utils-image / /
COPY --chmod=755 scripts/*.sh /

RUN <<EOT
apt-get update
apt-get install -y \
  pcscd \
  pcsc-tools \
  libccid \
  libpcsclite1
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
ldconfig
EOT

EXPOSE 40772 9229
ENTRYPOINT ["/entrypoint.sh"]