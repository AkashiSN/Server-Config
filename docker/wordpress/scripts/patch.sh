run_as() {
  if [ "$(id -u)" = 0 ]; then
    su -p www-data -s /bin/sh -c "$1"
  else
    sh -c "$1"
  fi
}

if ! run_as 'wp core is-installed'; then
  run_as "wp core install --url=${WORDPRESS_URL} --locale=ja --title=${WORDPRESS_TITLE} --admin_user=$(cat ${WORDPRESS_ADMIN_USER_FILE}) --admin_email=$(cat ${WORDPRESS_ADMIN_EMAIL}) --prompt=admin_password < ${WORDPRESS_ADMIN_PASSWORD_FILE}"
  run_as "wp core language install ja --activate"
  run_as "wp option update timezone_string $(wp eval "echo _x( '0', 'default GMT offset or timezone string' );")"
  run_as "wp option update date_format $(wp eval "echo __( 'M jS Y' );")"
fi

run_as "wp plugin install redis-cache --activate"
run_as "wp config set WP_REDIS_HOST wordpress-redis"

exec "$@"