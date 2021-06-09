#!/bin/bash
set -eu

if [ $# -lt 1 ]; then
	echo "Please specify backup datetime."
  exit 1
fi

DATETIME="$1"

echo "Use: ${DATETIME}"

BACKUP_DIR="/mnt/backup/nextcloud"
DATABASE_BACKUP="${BACKUP_DIR}/nextcloud-sql-${DATETIME}.sql"
DIRECTORY_BACKUP="${BACKUP_DIR}/nextcloud-dir-${DATETIME}.tar.gz"

if [ ! -e ${DATABASE_BACKUP} ];then
  echo "${DATABASE_BACKUP} is not exists."
fi

if [ ! -e ${DIRECTORY_BACKUP} ];then
  echo "${DIRECTORY_BACKUP} is not exists."
fi

if [ -e /var/www/html/index.php ]; then
  echo "Maintenance mode on"
  php /var/www/html/occ maintenance:mode --on

  echo "Remove exists nextcloud dir"
  shopt -s dotglob
  rm /var/www/html/*
  shopt -u dotglob
fi

echo "Restore nextcloud dir"
tar xf "${DIRECTORY_BACKUP}" -C /var/www/html .

echo "Drop exists database"
mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -e "DROP DATABASE ${MYSQL_DATABASE}"

echo "Create new database"
mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} -e "CREATE DATABASE ${MYSQL_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"

echo "Restore from backuped database"
mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} --database ${MYSQL_DATABASE} < "${DATABASE_BACKUP}"

echo "Maintenance mode off"
php /var/www/html/occ maintenance:mode --off
