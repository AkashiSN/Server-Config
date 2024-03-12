# syntax = docker/dockerfile:1.4

ARG UMS_VERSION="13.6.0" \
    LIB_ZEN_VERSION="0.4.41" \
    LIB_MEDIAINFO_VERSION="23.06"

FROM ubuntu:22.04 AS ums-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /workdir
ARG UMS_VERSION \
    LIB_ZEN_VERSION \
    LIB_MEDIAINFO_VERSION
ENV UMS_VERSION="${UMS_VERSION}" \
    LIB_ZEN_VERSION="${LIB_ZEN_VERSION}" \
    LIB_MEDIAINFO_VERSION="${LIB_MEDIAINFO_VERSION}"

RUN <<EOT
apt-get update
apt-get install -y \
  git \
  libmms0 \
  maven \
  openjdk-17-jdk \
  wget

wget https://mediaarea.net/download/binary/libzen0/${LIB_ZEN_VERSION}/libzen0v5_${LIB_ZEN_VERSION}-1_amd64.xUbuntu_22.04.deb
dpkg -i libzen0v5_${LIB_ZEN_VERSION}-1_amd64.xUbuntu_22.04.deb

wget https://mediaarea.net/download/binary/libmediainfo0/${LIB_MEDIAINFO_VERSION}/libmediainfo0v5_${LIB_MEDIAINFO_VERSION}-1_amd64.xUbuntu_22.04.deb
dpkg -i libmediainfo0v5_${LIB_MEDIAINFO_VERSION}-1_amd64.xUbuntu_22.04.deb

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

git clone https://github.com/UniversalMediaServer/UniversalMediaServer.git -b ${UMS_VERSION}
cd UniversalMediaServer

mvn package -P linux-x86_64

mkdir -p /build
cd /build
tar xvf /workdir/UniversalMediaServer/target/ums-${UMS_VERSION}-distribution.tar.gz
EOT


FROM ubuntu:22.04

SHELL ["/bin/bash", "-e", "-c"]
ARG UMS_VERSION \
    LIB_ZEN_VERSION \
    LIB_MEDIAINFO_VERSION
ENV UMS_VERSION="${UMS_VERSION}" \
    LIB_ZEN_VERSION="${LIB_ZEN_VERSION}" \
    LIB_MEDIAINFO_VERSION="${LIB_MEDIAINFO_VERSION}"
WORKDIR /workdir

COPY --from=ums-build /build/ /opt/

RUN <<EOT
apt-get update
apt-get install -y \
  dcraw \
  libcurl3-gnutls \
  libmms0 \
  mencoder \
  mplayer \
  openjdk-17-jre \
  p7zip \
  vlc \
  wget

wget https://mediaarea.net/download/binary/libzen0/${LIB_ZEN_VERSION}/libzen0v5_${LIB_ZEN_VERSION}-1_amd64.xUbuntu_22.04.deb
dpkg -i libzen0v5_${LIB_ZEN_VERSION}-1_amd64.xUbuntu_22.04.deb

wget https://mediaarea.net/download/binary/libmediainfo0/${LIB_MEDIAINFO_VERSION}/libmediainfo0v5_${LIB_MEDIAINFO_VERSION}-1_amd64.xUbuntu_22.04.deb
dpkg -i libmediainfo0v5_${LIB_MEDIAINFO_VERSION}-1_amd64.xUbuntu_22.04.deb

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
rm /workdir/*.deb

groupadd -g 1000 ums
useradd -m -s /bin/bash -u 1000 -g 1000 ums

mv /opt/ums-${UMS_VERSION} /opt/ums
chown -R ums:ums /opt/ums
mkdir -p /home/ums/.config/UMS
EOT

VOLUME [ "/home/ums/.config/UMS" ]
WORKDIR /opt/ums
USER ums
EXPOSE 9001 9002

ENTRYPOINT [ "/bin/sh", "/opt/ums/UMS.sh" ]
