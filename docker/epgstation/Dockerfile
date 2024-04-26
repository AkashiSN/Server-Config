# syntax = docker/dockerfile:1.4
FROM l3tnun/epgstation:v2.7.3-debian AS epgstation-image
FROM akashisn/ffmpeg:6.0 AS ffmpeg-image

RUN <<EOT
mkdir -p /dist
cp --archive --parents --no-dereference /usr/local/bin/ff* /dist
cp --archive --parents --no-dereference /usr/local/lib/* /dist
EOT


FROM ubuntu:24.04

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/local/lib \
    LIBVA_DRIVERS_PATH=/usr/local/lib/dri \
    LIBVA_DRIVER_NAME=iHD

COPY --from=epgstation-image /app /app
COPY --from=ffmpeg-image /dist /

RUN <<EOT
# Install Nodejs
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gettext \
  gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
EOT

EXPOSE 8888
WORKDIR /app

ENTRYPOINT ["npm", "start"]
