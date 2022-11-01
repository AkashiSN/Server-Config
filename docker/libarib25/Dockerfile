# syntax = docker/dockerfile:1.4
FROM buildpack-deps:buster AS arib25-build

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

COPY --chmod=755 ./arib-b25-stream /usr/local/bin/

RUN <<EOT
apt-get update
apt-get install -y \
  cmake \
  curl \
  libpcsclite-dev
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

curl -o /tmp/libarib25-master.tar.gz https://github.com/stz2012/libarib25/archive/master.tar.gz
tar xf /tmp/libarib25-master.tar.gz -C /tmp/

cd /tmp/libarib25-master
cmake -DCMAKE_BUILD_TYPE=Release -DLDCONFIG_EXECUTABLE=IGNORE .
make -j$(nproc)
make install

mkdir /build
cp --archive --parents --no-dereference /usr/local/bin/ /build
cp --archive --parents --no-dereference /usr/local/lib/ /build
cp --archive --parents --no-dereference /usr/local/include/ /build
rm -r /build/usr/local/lib/python*
EOT

FROM scratch

COPY --from=arib25-build /build /
