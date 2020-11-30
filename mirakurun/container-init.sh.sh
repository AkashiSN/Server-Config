#!/bin/bash

export SERVER_CONFIG_PATH=/app-config/server.yml
export TUNERS_CONFIG_PATH=/app-config/tuners.yml
export CHANNELS_CONFIG_PATH=/app-config/channels.yml
export SERVICES_DB_PATH=/app-data/services.json
export PROGRAMS_DB_PATH=/app-data/programs.json

export DOCKER=YES

if [ -e "/etc/init.d/pcscd" ]; then
  while :; do
    echo "starting pcscd..."
    /etc/init.d/pcscd start
    sleep 1
    timeout 2 pcsc_scan | grep -A 50 "Using reader plug'n play mechanism"
    if [ $? = 0 ]; then
      break;
    fi
    echo "failed!"
  done
fi

if [ "$DEBUG" != "true" ]; then
  npm run start
else
  npm run debug
fi

if [ -e "/etc/init.d/pcscd" ]; then
  echo "stopping pcscd..."
  /etc/init.d/pcscd stop
  sleep 1
fi