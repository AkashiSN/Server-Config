FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

# Install cups
RUN apt-get update && \
    apt-get install -y curl cups

# Install capt
RUN curl -sL -o /tmp/linux-capt-drv-v271-jp.tar.gz https://gdlp01.c-wss.com/gds/7/0100003447/08/linux-capt-drv-v271-jp.tar.gz && \
    tar xvf /tmp/linux-capt-drv-v271-jp.tar.gz -C /tmp && \
    apt-get install -y /tmp/linux-capt-drv-v271-jp/64-bit_Driver/Debian/cndrvcups-common_3.21-1_amd64.deb /tmp/linux-capt-drv-v271-jp/64-bit_Driver/Debian/cndrvcups-capt_2.71-1_amd64.deb && \
    rm -rf /tmp/linux-capt-drv-v271-jp*

RUN sed -i 's!Listen localhost:631!Listen 0.0.0.0:631!' /etc/cups/cupsd.conf && \
    sed -i 's!Browsing Off!Browsing On!' /etc/cups/cupsd.conf && \
    sed -i 's!<Location />!<Location />\n  Allow All!' /etc/cups/cupsd.conf && \
    sed -i 's!<Location /admin>!<Location /admin>\n  Allow All\n  Require user @SYSTEM!' /etc/cups/cupsd.conf && \
    sed -i 's!<Location /admin/conf>!<Location /admin/conf>\n  Allow All!' /etc/cups/cupsd.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf

COPY run.sh /usr/bin/run.sh

ENTRYPOINT ["/usr/bin/run.sh"]
