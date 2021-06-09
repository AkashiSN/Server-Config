# Nextcloud

## Backup

```bash
$ docker-compose exec -u www-data nextcloud backup.sh
```

## Restore

```bash
$ docker-compose exec -u www-data nextcloud restore.sh ${DATETIME}
```