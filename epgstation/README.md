# EPGStation

## Backup

```bash
$ DATETIME=$(date +"%Y%m%d%H%M%S")
$ echo ${DATETIME}
$ docker compose exec epgstation npm run backup /mnt/backup/epgstation/${DATETIME}.tar.gz
```

## Restore

Restore by running the following before docker compose up.

```bash
$ docker compose up -d mirakurun mariadb_epgstation
$ docker compose run --rm --entrypoint=npm epgstation run restore /mnt/backup/epgstation/${DATETIME}.tar.gz
```