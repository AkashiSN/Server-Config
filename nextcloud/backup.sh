#!/bin/bash
set -eu

function search_file() {
  echo $(find "$1" -maxdepth 1 -name "$2" -printf "%T+ %p\n" | sort | cut -d " " -f 2)
}

DATETIME=$(date +"%Y%m%d%H%M%S")
echo "Now: ${DATETIME}"

BACKUP_DIR="/mnt/backup/nextcloud"
DATABASE_BACKUP="${BACKUP_DIR}/nextcloud-sql-${DATETIME}.sql"
DIRECTORY_BACKUP="${BACKUP_DIR}/nextcloud-dir-${DATETIME}.tar.gz"

MAX_BACKUP=30

SQL_BACKUP_LIST=($(search_file ${BACKUP_DIR} '*.sql'))
if [ ${#SQL_BACKUP_LIST[@]} -gt ${MAX_BACKUP} ]; then # 最大バックアップ数より多い場合古いバックアップを削除する
  for SQL_BACKUP in "${SQL_BACKUP_LIST[@]: 0:$((${#SQL_BACKUP_LIST[@]}-${MAX_BACKUP}))}"; do
    echo "Remove ${SQL_BACKUP}"
    rm ${SQL_BACKUP}
  done
fi

DIR_BACKUP_LIST=($(search_file ${BACKUP_DIR} '*.tar.gz'))
if [ ${#DIR_BACKUP_LIST[@]} -gt ${MAX_BACKUP} ]; then # 最大バックアップ数より多い場合古いバックアップを削除する
  for DIR_BACKUP in "${DIR_BACKUP_LIST[@]: 0:$((${#DIR_BACKUP_LIST[@]}-${MAX_BACKUP}))}"; do
    echo "Remove ${DIR_BACKUP}"
    rm ${DIR_BACKUP}
  done
fi

echo "Maintenance mode on"
php /var/www/html/occ maintenance:mode --on

echo "Backup nextcloud dir"
tar zcf "${DIRECTORY_BACKUP}" -C /var/www/html .

echo "Backup nextcloud database"
mysqldump --single-transaction --databases ${MYSQL_DATABASE} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -h${MYSQL_HOST} > "${DATABASE_BACKUP}"

echo "Maintenance mode off"
php /var/www/html/occ maintenance:mode --off
