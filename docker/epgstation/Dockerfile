# syntax = docker/dockerfile:1.4
ARG FFMPEG_VERSION=5.0.1
ARG EPGSTATION_VERSION=2.6.20

FROM l3tnun/epgstation:v${EPGSTATION_VERSION}-debian AS epgstation-image
FROM akashisn/ffmpeg:${FFMPEG_VERSION}-qsv AS ffmpeg-image

RUN <<EOT
mkdir /build
cp --archive --parents --no-dereference /usr/local/bin/ff* /build
cp --archive --parents --no-dereference /usr/local/lib/*.so* /build
EOT

FROM ubuntu:22.04

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV LIBVA_DRIVERS_PATH=/usr/local/lib
ENV LIBVA_DRIVER_NAME=iHD

COPY --from=epgstation-image /app /app
COPY --from=ffmpeg-image /build /

RUN <<EOT
apt-get update
apt-get install -y \
  curl \
  gettext \
  libdrm2
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
ldconfig
EOT

EXPOSE 8888
WORKDIR /app
