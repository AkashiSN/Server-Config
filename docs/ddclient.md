## Install

```bash
# Install ddclient dependencies.
sudo apt install -y libdata-validate-ip-perl libio-socket-inet6-perl net-tools

# Install ddclient without prompt.
sudo DEBIAN_FRONTEND=noninteractive apt install -y ddclient
```

```bash
# Create work directory
mkdir -p ~/work
cd ~/work

# Download ddclinet source
wget https://github.com/ddclient/ddclient/archive/v3.9.1.tar.gz
tar xvf v3.9.1.tar.gz
cd ddclient-3.9.1

# Copy overwrite ddclinet
sudo cp ddclient /usr/sbin/ddclient
sudo mkdir /etc/ddclient
sudo rm /etc/ddclient.conf
```

```bash
# Disable daemon
cat /etc/default/ddclient
....
run_daemon="false"
....

# Disable service
sudo systemctl stop ddclient
sudo systemctl disable ddclient
sudo update-rc.d -f ddclient remove
```

## Setup

```bash
sudo vim /etc/ddclient/ddclient_v4.conf
```

```bash
##
## sub.domain.tld - IPv4 - Cloudflare
##
ipv6=no
ssl=yes
ttl=1
protocol=cloudflare
use=web, web=https://v4.ident.me/
login=<email>
password=<global api key>
cache=/var/cache/ddclient/ddclient_v4.cache
zone=domain.tld
sub.domain.tld,sub1.domain.tld
```

```bash
sudo vim /etc/ddclient/ddclient_v6.conf
```

```bash
##
## sub.domain.tld - IPv6 - Cloudflare
##
ipv6=yes
ssl=yes
ttl=1
protocol=cloudflare
use=web, web=https://v6.ident.me/
login=<email>
password=<global api key>
cache=/var/cache/ddclient/ddclient_v6.cache
zone=domain.tld
sub.domain.tld
```

```bash
# Check correctly.
sudo ddclient -daemon=0 -verbose -noquiet -file /etc/ddclient/ddclient_v4.conf
sudo ddclient -daemon=0 -verbose -noquiet -file /etc/ddclient/ddclient_v6.conf
```

```bash
# Clear cache.
sudo rm /var/cache/ddclient/ddclient_v4.cache
sudo rm /var/cache/ddclient/ddclient_v6.cache
```

```bash
# Set crontab.
cat << 'EOS' | sudo tee -a /etc/crontab
*/5 *   * * *   root    (/usr/sbin/ddclient -file /etc/ddclient/ddclient_v4.conf; /usr/sbin/ddclient -file /etc/ddclient/ddclient_v6.conf) | /usr/bin/logger -t ddclient
EOS

# Restart cron
sudo /etc/init.d/cron restart

# Log
sudo tail -f /var/log/syslog
```
