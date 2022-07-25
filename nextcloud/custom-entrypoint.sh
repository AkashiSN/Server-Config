#!/bin/sh
set -eu

run_as() {
    if [ "$(id -u)" = 0 ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run_as 'php /var/www/html/occ app:enable files_external'
run_as 'php /var/www/html/occ app:enable twofactor_totp'

run_as 'php /var/www/html/occ config:system:set default_phone_region --value=JP'
run_as 'php /var/www/html/occ config:system:set maintenance_window_start --value=1'

exec "$@"