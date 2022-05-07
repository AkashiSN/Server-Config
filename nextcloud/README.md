# Nextcloud

## Backup

```bash
$ docker compose exec -u www-data nextcloud backup.sh
```

## Restore

Restore by running the following before docker compose up.

```bash
$ docker compose up -d mariadb_nextcloud redis_nextcloud
$ docker compose run --rm -u www-data --entrypoint=restore.sh nextcloud ${DATETIME}
```