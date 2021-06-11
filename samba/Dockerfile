FROM  ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y samba && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && \
    \
    useradd -o -M -s /sbin/nologin -u 33 -g 33 samba

COPY ./entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 139 445
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
