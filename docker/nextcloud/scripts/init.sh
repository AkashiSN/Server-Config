#!/bin/sh
set -eu

chmod 0770 "${NEXTCLOUD_DATA_DIR}"

chown www-data:www-data "${EXTERNAL_DIR}"
chmod 0770 "${EXTERNAL_DIR}"

exec "$@"