# syntax = docker/dockerfile:1.4
FROM buildpack-deps:buster AS v4l-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

COPY ./patch/v4l-utils-1.22.1.patch /tmp/v4l-utils-1.22.1.patch

RUN <<EOT
apt-get update
apt-get install -y \
  autopoint \
  curl \
  gettext \
  libelf-dev \
  libudev-dev \
  systemd \
  udev

curl -L -o /tmp/v4l-utils-1.22.1.tar.bz2 https://linuxtv.org/downloads/v4l-utils/v4l-utils-1.22.1.tar.bz2
tar xf /tmp/v4l-utils-1.22.1.tar.bz2 -C /tmp/
patch -u -d /tmp/v4l-utils-1.22.1 -p 1 < /tmp/v4l-utils-1.22.1.patch

cd /tmp/v4l-utils-1.22.1
./bootstrap.sh
./configure --disable-doxygen-doc --disable-doxygen-dot --disable-v4l2-compliance-libv4l \
    --disable-v4l2-ctl-libv4l --disable-qv4l2 --enable-gconv --enable-shared
make -j$(nproc) CFLAGS="-fPIC"
make install

cd /tmp/v4l-utils-1.22.1/contrib/gconv
make install

mkdir /build
cp --archive --parents --no-dereference /usr/local/bin/ /build
cp --archive --parents --no-dereference /usr/local/lib/ /build
cp --archive --parents --no-dereference /usr/local/include/ /build
rm -rf /build/usr/local/lib/python*
EOT

FROM scratch

COPY --from=v4l-build /build /
