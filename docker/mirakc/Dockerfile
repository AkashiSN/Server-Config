# syntax = docker/dockerfile:1.4
FROM buildpack-deps:bookworm AS buildpack-base
SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  cmake

cat <<EOF >/toolchain.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER gcc)
set(CMAKE_C_COMPILER_TARGET x86_64-linux-gnu)
set(CMAKE_CXX_COMPILER g++)
set(CMAKE_CXX_COMPILER_TARGET x86_64-linux-gnu)
EOF
EOT


FROM buildpack-base AS mirakc-arib-build
ENV MIRAKC_ARIB_VERSION=0.21.14
RUN <<EOT
git clone --recursive https://github.com/mirakc/mirakc-arib.git -b ${MIRAKC_ARIB_VERSION} --depth=1 /tmp/mirakc-arib
cd /tmp/mirakc-arib

cmake -S . -B build -D CMAKE_BUILD_TYPE=Release -D CMAKE_TOOLCHAIN_FILE=/toolchain.cmake
make -C build -j $(nproc) vendor
make -C build -j $(nproc)
strip ./build/bin/mirakc-arib

mkdir -p /dist/usr/local/bin/
cp ./build/bin/mirakc-arib /dist/usr/local/bin/
EOT


FROM buildpack-base AS arib25-build
RUN <<EOT
apt-get install -y \
  libpcsclite-dev

git clone https://github.com/stz2012/libarib25.git --depth=1 /tmp/libarib25
cd /tmp/libarib25

cmake -S . -B build -D CMAKE_BUILD_TYPE=Release -D CMAKE_TOOLCHAIN_FILE=/toolchain.cmake
make -C build -j $(nproc)

cat <<EOF >./arib-b25-stream
#!/bin/sh
b25 - -
EOF
chmod +x ./arib-b25-stream

mkdir -p /dist/usr/local/{bin,lib}/
cp ./arib-b25-stream /dist/usr/local/bin/
cp ./build/b25 /dist/usr/local/bin/
cp -d ./build/libarib25.so* /dist/usr/local/lib/
EOT


FROM buildpack-base AS v4l-build
ENV V4L_VERSION=1.24.1
RUN <<EOT
apt-get install -y \
  libasound2-dev \
  libelf-dev \
  libudev-dev

curl -L -o /tmp/v4l-utils.tar.bz2 https://linuxtv.org/downloads/v4l-utils/v4l-utils-${V4L_VERSION}.tar.bz2
mkdir -p /tmp/v4l-utils && cd /tmp/v4l-utils
tar xf /tmp/v4l-utils.tar.bz2 -C . --strip-components 1

./configure --disable-doxygen-doc --enable-gconv
make -j$(nproc) CFLAGS="-fPIC"
make install

git clone https://github.com/Chinachu/dvbconf-for-isdb.git --depth 1 /tmp/dvbconf
cat /tmp/dvbconf/conf/dvbv5_channels_isdb{t,s}.conf > /tmp/dvbv5_channels_isdb.conf

mkdir -p /dist/usr/local/{bin,lib,etc/dvbv5}/
cp /usr/local/bin/dvb* /dist/usr/local/bin/
cp -d /usr/local/lib/libdvbv5.so* /dist/usr/local/lib/
cp -r /usr/local/lib/gconv /dist/usr/local/lib/
cp /tmp/dvbv5_channels_isdb.conf /dist/usr/local/etc/dvbv5/
EOT


FROM rust:bookworm as mirakc-build
SHELL ["/bin/bash", "-e", "-c"]
ENV MIRAKC_VERSION=2.4.11 \
    DEBIAN_FRONTEND=noninteractive

RUN <<EOT
git clone https://github.com/mirakc/mirakc.git -b ${MIRAKC_VERSION} --depth=1 /tmp/mirakc
cd /tmp/mirakc
cargo build --profile=release --bin mirakc
cargo build --profile=release --bin mirakc-timeshift-fs

cat <<EOF >./run-mirakc-timeshift-fs
#!/bin/sh
trap 'umount /mnt' EXIT
/usr/local/bin/mirakc-timeshift-fs /mnt
EOF
chmod +x ./run-mirakc-timeshift-fs

mkdir -p /dist/usr/local/bin/
cp ./target/release/mirakc /dist/usr/local/bin/
cp ./run-mirakc-timeshift-fs /dist/usr/local/bin/
cp ./target/release/mirakc-timeshift-fs /dist/usr/local/bin/
mkdir -p /dist/etc/mirakc/
cp ./resources/strings.yml /dist/etc/mirakc/strings.yml
EOT


FROM debian:bookworm-slim AS mirakc
SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    GCONV_PATH=/usr/local/lib/gconv \
    MIRAKC_CONFIG=/etc/mirakc/config.yml \
    MIRAKC_BUILD_PROFILE=release

COPY --from=mirakc-arib-build /dist /
COPY --from=arib25-build /dist /
COPY --from=v4l-build /dist /
COPY --from=mirakc-build /dist /

RUN <<EOT
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  jq \
  libccid \
  libpcsclite1 \
  libudev1 \
  pcsc-tools \
  pcscd \
  socat
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
EOT

COPY --chmod=755 entrypoint.sh /

EXPOSE 40772
ENTRYPOINT ["/entrypoint.sh"]
CMD []
