# Nextcloud

## Backup

```bash
$ docker-compose exec -u www-data nextcloud backup.sh
```

## Restore

```bash
$ docker-compose up -d mariadb_nextcloud redis_nextcloud
$ docker-compose run -u www-data nextcloud restore.sh ${DATETIME}
```