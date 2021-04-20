#!/bin/bash
set -a; source .env; set +a;

BACKUP_COUNT=$(ls -U1 ${NAS_PATH}/backup/nextcloud/ | wc -l)
if [ ${BACKUP_COUNT} -ge 14 ]; then
  echo "Remove backup file"
  rm ${NAS_PATH}/backup/nextcloud/*
fi

echo "Maintenance mode on"
docker-compose exec -u www-data nextcloud php ./occ maintenance:mode --on
echo "Backup nextcloud dir"
docker-compose exec -u www-data nextcloud tar zcf ${NAS_PATH}/backup/nextcloud/nextcloud-dirbkp_`date +"%Y%m%d-%H%M%S"`.tar.gz -C /var/www/html .
echo "Backup nextcloud database"
docker-compose exec mariadb_nextcloud mysqldump --single-transaction --databases ${MYSQL_NEXTCLOUD_DATABASE} -uroot -p${MYSQL_NEXTCLOUD_ROOT_PASSWORD} > ${NAS_PATH}/backup/nextcloud/nextcloud-sqlbkp_`date +"%Y%m%d-%H%M%S"`.sql
echo "Maintenance mode off"
docker-compose exec -u www-data nextcloud php ./occ maintenance:mode --off


# docker-compose exec -u www-data nextcloud php ./occ maintenance:mode --on
# docker-compose exec -u www-data nextcloud tar xf ${NAS_PATH}/backup/nextcloud/nextcloud-dirbkp_`date +"%Y%m%d-%H%M%S"`.tar.gz -C /var/www/html .
# docker-compose exec mariadb_nextcloud mysql -uroot -p${MYSQL_NEXTCLOUD_ROOT_PASSWORD} -e "DROP DATABASE nextcloud"
# docker-compose exec mariadb_nextcloud mysql -uroot -p${MYSQL_NEXTCLOUD_ROOT_PASSWORD} -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
# docker-compose exec mariadb_nextcloud mysql -uroot -p${MYSQL_NEXTCLOUD_ROOT_PASSWORD} --databases ${MYSQL_NEXTCLOUD_DATABASE} < ${NAS_PATH}/backup/nextcloud/nextcloud-sqlbkp_`date +"%Y%m%d-%H%M%S"`.sql
