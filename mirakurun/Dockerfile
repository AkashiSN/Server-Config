# dvb tools build
FROM ubuntu:20.04 as dvb-tools

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /workdir

# Install buld tools
RUN apt-get update && \
    apt-get install -y curl build-essential gettext automake autopoint libtool pkg-config && \
    apt-get install -y udev libudev-dev systemd libjpeg-dev libelf-dev

# Download v4l-utils
RUN curl -L -o /workdir/v4l-utils-1.20.0.tar.bz2 https://linuxtv.org/downloads/v4l-utils/v4l-utils-1.20.0.tar.bz2 && \
    tar xvf /workdir/v4l-utils-1.20.0.tar.bz2 -C /workdir/

# Build v4l-utils
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
RUN cd /workdir/v4l-utils-1.20.0 && \
    ./bootstrap.sh && \
    ./configure --disable-doxygen-doc --disable-doxygen-dot --disable-v4l2-compliance-libv4l \
        --disable-v4l2-ctl-libv4l --disable-qv4l2 --enable-gconv --enable-shared && \
    make -j$(nproc) CFLAGS="-fPIC" && \
    make install

# Build gconv
RUN cd /workdir/v4l-utils-1.20.0/contrib/gconv && \
    make install


# libarib25 build
FROM ubuntu:20.04 as libarib25

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /workdir

# Install buld tools
RUN apt-get update && \
    apt-get install -y curl build-essential cmake && \
    apt-get install -y libpcsclite-dev

# Download libarib25
RUN curl -L -o /workdir/libarib25.tar.gz https://github.com/stz2012/libarib25/archive/master.tar.gz && \
    tar xvf /workdir/libarib25.tar.gz -C /workdir/

# Build libarib25
RUN cd /workdir/libarib25-master && \
    cmake . && \
    make -j$(nproc) && \
    make install

# Mirakurun
FROM chinachu/mirakurun as mirakurun

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV GCONV_PATH=/usr/local/lib/gconv

# Copy dvb-tools
COPY --from=dvb-tools /usr/local/bin/dvb* /usr/local/bin/
COPY --from=dvb-tools /usr/local/lib/libdvbv5.so* /usr/local/lib/
COPY --from=dvb-tools /usr/local/lib/gconv /usr/local/lib/gconv/
