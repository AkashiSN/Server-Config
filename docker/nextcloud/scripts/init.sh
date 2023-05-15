#!/bin/sh
set -eu

chmod 0770 "${NEXTCLOUD_DATA_DIR}"

if [ -n "${EXTERNAL_DIR}" ]; then
  chown www-data:www-data "${EXTERNAL_DIR}"
  chmod 0770 "${EXTERNAL_DIR}"
fi

exec "$@"