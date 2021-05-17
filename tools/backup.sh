#!/bin/bash
set -eu

if [ $# -lt 1 ]; then
  exit 1
fi

function get_timestamp() {
	echo $1 | awk '{split($0, snap, "@"); print snap[2]}'
}

#DATASETS=("archives" "books" "musics" "nextcloud" "videos" "backup")
DATASETS=("$@")

LOCAL_POOL="nas"
REMOTE_POOL="tank"
REMOTE_HOST="backup"

MAX_SNAPSHOTS=30
DATETIME=$(date +"%Y%m%d%H%M%S")

echo "Now: ${DATETIME}"

for DATASET in "${DATASETS[@]}"; do
	echo "Create a snapshot of ${DATASET}"
	zfs snapshot ${LOCAL_POOL}/${DATASET}@${DATETIME}
done

for DATASET in "${DATASETS[@]}"; do
	echo "Back up of ${LOCAL_POOL}/${DATASET}@${DATETIME}"

	LOCAL_SNAPSHOTS=($(zfs list -H -o name -t snapshot ${LOCAL_POOL}/${DATASET}))
	echo "There are ${#LOCAL_SNAPSHOTS[@]} snapshots in local."

	REMOTE_SNAPSHOTS=($(ssh ${REMOTE_HOST} zfs list -H -o name -t snapshot ${REMOTE_POOL}/${DATASET}))
	echo "There are ${#REMOTE_SNAPSHOTS[@]} snapshots in ${REMOTE_HOST}."

	if [ ${#REMOTE_SNAPSHOTS[@]} -eq 0 ]; then # リモートにスナップショットが存在しない

		echo "Transfer the base snapshot to the remote."
		# ベーススナップショットを転送する
		zfs send ${LOCAL_SNAPSHOTS[0]} | ssh ${REMOTE_HOST} zfs recv -F ${REMOTE_POOL}/${DATASET}
		echo "Transfer complete."

		if [ ${#LOCAL_SNAPSHOTS[@]} -ne 1 ]; then # ローカルにベーススナップショット以外が存在する

			echo "Transfer all differential snapshots to the remote."
			# 全ての差分スナップショットを転送する
			zfs send -I ${LOCAL_SNAPSHOTS[0]} ${LOCAL_SNAPSHOTS[-1]} | ssh ${REMOTE_HOST} zfs recv ${REMOTE_POOL}/${DATASET}
			echo "Transfer complete."

		fi

	elif [ $(get_timestamp ${REMOTE_SNAPSHOTS[-1]}) = $(get_timestamp ${LOCAL_SNAPSHOTS[-2]}) ]; then # 差分の元となるスナップショットがリモートに存在する

		echo "Transfer a differential snapshot to the remote."
		# 差分スナップショットを転送する
		zfs send -i ${LOCAL_SNAPSHOTS[-2]} ${LOCAL_SNAPSHOTS[-1]} | ssh ${REMOTE_HOST} zfs recv ${REMOTE_POOL}/${DATASET}
		echo "Transfer complete."

	else # リモートとの整合性がとれない場合

		# リモートのスナップショットを削除
		for REMOTE_SNAPSHOT in "${REMOTE_SNAPSHOTS[@]}"; do
			ssh ${REMOTE_HOST} zfs destroy ${REMOTE_SNAPSHOT}
		done

		echo "Transfer the base snapshot to the remote."
		# ベーススナップショットを転送する
		zfs send ${LOCAL_SNAPSHOTS[0]} | ssh ${REMOTE_HOST} zfs recv -F ${REMOTE_POOL}/${DATASET}
		echo "Transfer complete."

		if [ ${#LOCAL_SNAPSHOTS[@]} -ne 1 ]; then # ローカルにベーススナップショット以外が存在する

			echo "Transfer all differential snapshots to the remote."
			# 全ての差分スナップショットを転送する
			zfs send -I ${LOCAL_SNAPSHOTS[0]} ${LOCAL_SNAPSHOTS[-1]} | ssh ${REMOTE_HOST} zfs recv ${REMOTE_POOL}/${DATASET}
			echo "Transfer complete."

		fi

	fi

	if [ ${#LOCAL_SNAPSHOTS[@]} -gt ${MAX_SNAPSHOTS} ]; then # 最大スナップショット数より多い場合削除する

		echo "Clear local snapshots."
		# 最新のスナップショット以外を削除する
		for LOCAL_SNAPSHOT in "${LOCAL_SNAPSHOTS[@]: 0:-1}"; do
			zfs destroy ${LOCAL_SNAPSHOT}
		done

	fi

	if [ ${#REMOTE_SNAPSHOTS[@]} -ge ${MAX_SNAPSHOTS} ]; then # 最大スナップショット数より多い場合削除する

		echo "Clear remote snapshots."
		# REMOTE_SNAPSHOTSは転送前のリストなので全て削除する
		for REMOTE_SNAPSHOT in "${REMOTE_SNAPSHOTS[@]}"; do
			zfs destroy ${REMOTE_SNAPSHOT}
		done

	fi

done
