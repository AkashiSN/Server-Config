# syntax = docker/dockerfile:1.4
FROM hackmdio/hackmd:2.4.2-cjk

# copy script to apply GROWI agent
COPY --chmod=755 apply-growi-agent.sh /codimd/apply-growi-agent.sh
# copy HackMD config file
COPY config.json /files/

RUN <<EOT
# run the script
/codimd/apply-growi-agent.sh

# overwrite HackMD config file
rm -f /codimd/config.json
ln -s /files/config.json /codimd/config.json

# create sqlite data dir
mkdir /files/sqlite
chown codimd /files/sqlite
ln -s /files/sqlite /codimd/sqlite
EOT
