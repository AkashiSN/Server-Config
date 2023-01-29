#!/bin/sh
set -eu

run_as() {
  if [ "$(id -u)" = 0 ]; then
    su -p www-data -s /bin/sh -c "$1"
  else
    sh -c "$1"
  fi
}

run_as 'wp plugin install redis-cache --activate'
run_as 'wp config set WP_REDIS_HOST wordpress-redis'

exec "$@"