# ffmpeg
FROM akashisn/ffmpeg AS ffmpeg

# epgstaion
FROM l3tnun/epgstation as epgstation

# release
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

RUN apt-get update && \
    apt-get install -y curl gettext && \
    apt-get install -y libva-drm2 && \
    curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Copy libnpp
COPY --from=ffmpeg /lib/x86_64-linux-gnu/libnppc.so.11 /lib/x86_64-linux-gnu/libnppc.so.11
COPY --from=ffmpeg /lib/x86_64-linux-gnu/libnppig.so.11 /lib/x86_64-linux-gnu/libnppig.so.11
COPY --from=ffmpeg /lib/x86_64-linux-gnu/libnppicc.so.11 /lib/x86_64-linux-gnu/libnppicc.so.11
COPY --from=ffmpeg /lib/x86_64-linux-gnu/libnppidei.so.11 /lib/x86_64-linux-gnu/libnppidei.so.11

# Copy ffmpeg
COPY --from=ffmpeg /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=ffmpeg /usr/bin/ffprobe /usr/bin/ffprobe
COPY --from=ffmpeg /usr/bin/ffplay /usr/bin/ffplay

# Copy epgstation
COPY --from=epgstation /app /app/

# Copy nvidia patch
RUN mkdir -p /patched-lib && \
    curl -sL -o /usr/local/bin/patch.sh https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh && \
    curl -sL -o /usr/local/bin/docker-entrypoint.sh https://raw.githubusercontent.com/keylase/nvidia-patch/master/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/patch.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
WORKDIR /app

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]