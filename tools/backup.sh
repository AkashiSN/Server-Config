#!/bin/bash
set -eu

if [ $# -lt 1 ]; then
  exit 1
fi

#DATASETS=("archives" "books" "musics" "nextcloud" "videos")
DATASETS=("$@")

LOCAL_POOL="nas"
REMOTE_POOL="tank"
REMOTE_HOST="backup"

MAX_SNAPSHOTS=7
DATETIME=$(date +"%Y%m%d%H%M%S")

for DATASET in "${DATASETS[@]}"; do
	echo "${DATASET}"

	LOCAL_SNAPSHOTS=($(zfs list -H -o name -t snapshot ${LOCAL_POOL}/${DATASET}))
	echo "There are ${#LOCAL_SNAPSHOTS[@]} snapshots in local."

	if [ ${#LOCAL_SNAPSHOTS[@]} -gt ${MAX_SNAPSHOTS} ]; then # 最大スナップショット数より多い場合削除する
		echo "Clean local snapshots."
		for LOCAL_SNAPSHOT in "${LOCAL_SNAPSHOTS[@]}"; do
			zfs destroy ${LOCAL_SNAPSHOT}
		done
		LOCAL_SNAPSHOTS=()
	fi

	if [ ${#LOCAL_SNAPSHOTS[@]} -eq 0 ]; then # ローカルにスナップショットがない場合
		REMOTE_SNAPSHOTS=($(ssh ${REMOTE_HOST} zfs list -H -o name -t snapshot ${REMOTE_POOL}/${DATASET}))
		echo "Clean remote snapshots."
		
		# リモートにスナップショットがある場合は、削除
		for REMOTE_SNAPSHOT in "${REMOTE_SNAPSHOTS[@]}"; do
			ssh ${REMOTE_HOST} zfs destroy ${REMOTE_SNAPSHOT}
		done

		# ローカルでベーススナップショットを作成する
		echo "Create local base snapshot."
		zfs snapshot ${LOCAL_POOL}/${DATASET}@${DATETIME}

		# ベーススナップショットを転送する
		echo "Send local base snapshot to remote."
		zfs send ${LOCAL_POOL}/${DATASET}@${DATETIME} | ssh ${REMOTE_HOST} zfs recv -F ${REMOTE_POOL}/${DATASET}
	else
		# ローカルで差分スナップショットを作成する
		echo "Create local diff snapshot."
		zfs snapshot ${LOCAL_POOL}/${DATASET}@${DATETIME}
		
		# 差分スナップショットを転送する
		echo "Send local diff snapshot to remote."
		zfs send -i ${LOCAL_SNAPSHOTS[-1]} ${LOCAL_POOL}/${DATASET}@${DATETIME} | ssh ${REMOTE_HOST} zfs recv -F ${REMOTE_POOL}/${DATASET}
	fi
done
