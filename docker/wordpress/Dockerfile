# syntax = docker/dockerfile:1.4
FROM wordpress:6.1.1-php8.2-fpm

SHELL ["/bin/bash", "-e", "-c"]
ENV DEBIAN_FRONTEND noninteractive

RUN <<EOT
apt-get update
apt-get install -y \
  sendmail \
  less
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

pecl install redis
docker-php-ext-enable redis

cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# patch custom entrypoint
sed -i '/exec "$@"/d' /usr/local/bin/docker-entrypoint.sh
cat << 'EOS' >> /usr/local/bin/docker-entrypoint.sh
su -p www-data -s /bin/sh << 'EOF'
if ! wp core is-installed; then
  wp core install --url=${WORDPRESS_URL} --locale=ja --title=${WORDPRESS_TITLE} --admin_user=$(cat ${WORDPRESS_ADMIN_USER_FILE}) --admin_email=$(cat ${WORDPRESS_ADMIN_EMAIL_FILE}) --prompt=admin_password < ${WORDPRESS_ADMIN_PASSWORD_FILE}
  wp core language install ja --activate
  wp option update timezone_string $(wp eval "echo _x( '0', 'default GMT offset or timezone string' );")
  wp option update date_format $(wp eval "echo __( 'M jS Y' );")
fi

wp plugin install redis-cache --activate
wp plugin install wordfence-login-security --activate
wp plugin install insert-headers-and-footers --activate
wp config set WP_REDIS_HOST wordpress-redis
wp config set DISABLE_WP_CRON true
EOF

exec "$@"
EOS
EOT

COPY config/zz-docker.conf /usr/local/etc/php-fpm.d/
COPY config/wordpress.ini /usr/local/etc/php/conf.d/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]