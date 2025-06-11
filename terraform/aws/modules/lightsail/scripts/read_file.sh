#!/bin/bash
set -e

eval "$(jq -r '@sh "host=\(.host) user=\(.user) key=\(.key) path=\(.path)"')"

content=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${key}" "${user}@${host}" "sudo cat ${path}")

jq -n --arg content "$content" '{"content":$content}'
