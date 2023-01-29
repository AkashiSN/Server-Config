su -p www-data -s /bin/sh
  if ! wp core is-installed; then
    wp core install --url=${WORDPRESS_URL} --locale=ja --title=${WORDPRESS_TITLE} --admin_user=$(cat ${WORDPRESS_ADMIN_USER_FILE}) --admin_email=$(cat ${WORDPRESS_ADMIN_EMAIL_FILE}) --prompt=admin_password < ${WORDPRESS_ADMIN_PASSWORD_FILE}
    wp core language install ja --activate
    wp option update timezone_string $(wp eval "echo _x( '0', 'default GMT offset or timezone string' );")
    wp option update date_format $(wp eval "echo __( 'M jS Y' );")
    wp plugin install redis-cache --activate
    wp config set WP_REDIS_HOST wordpress-redis
  fi
exit

exec "$@"