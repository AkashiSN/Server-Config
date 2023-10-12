#!/bin/bash
function trap_exit() {
  echo "stopping... $(jobs -p)"
  kill $(jobs -p) > /dev/null 2>&1 || echo "already killed."
  /etc/init.d/pcscd stop
  sleep 1
  echo "exit."
}

function start_pcscd() {
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
}

function restart_mirakc() {
  echo "restarting... $(jobs -p)"
  kill $(jobs -p) > /dev/null 2>&1 || echo "already killed."
  sleep 1
  start_mirakc
}

function start_mirakc() {
  /usr/local/bin/mirakc &

  wait
}

trap trap_exit 0
trap restart_mirakc 1
trap "exit 0" 2 3 15

start_pcscd

start_mirakc
