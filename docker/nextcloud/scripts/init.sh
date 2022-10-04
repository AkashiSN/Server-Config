#!/bin/sh
set -eu

chmod 0770 ${NEXTCLOUD_DATA_DIR}

exec "$@"