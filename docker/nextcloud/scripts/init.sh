#!/bin/bash
set -eu

chmod 0770 "${NEXTCLOUD_DATA_DIR}"

set +u
if [ -n "${EXTERNAL_DIRS}" ]; then
  IFS=',' read -r -a EXTERNAL_DIRS_LIST <<< "$EXTERNAL_DIRS"
  for dir in "${EXTERNAL_DIRS_LIST[@]}"; do
    echo "${dir}"
  done
fi
set -u

exec "$@"