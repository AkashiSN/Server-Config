#!/bin/bash
set -eu

if [ $# -lt 1 ]; then
  exit 1
fi

#DATASETS=("archives" "books" "musics" "nextcloud" "samba" "backup")
DATASETS=("$@")

LOCAL_POOL="nas"
REMOTE_POOL="tank"
REMOTE_HOST="backup"

MAX_SNAPSHOTS=30
DATETIME=$(date +"%Y%m%d%H%M%S")

echo "Now: ${DATETIME}"

function get_timestamp() {
  echo "$1" | awk '{split($0, snap, "@"); print snap[2]}'
}

# search_timestamp target_snapshot snapshots...
function search_timestamp() {
  local target_timestamp=$(get_timestamp "$1")
  shift

  local snapshots=("$@")

  for snapshot in ${snapshots[@]}; do
    if [ $(get_timestamp "$snapshot") = $target_timestamp ] ;then
      echo "$snapshot"
      return 0
    fi
  done

  return 1
}

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

  # リモートにスナップショットが存在しない
  if [ ${#REMOTE_SNAPSHOTS[@]} -eq 0 ]; then

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

  # リモートにスナップショットが存在する
  else

    result=0
    base_snapshot=$(search_timestamp ${REMOTE_SNAPSHOTS[-1]} "${LOCAL_SNAPSHOTS[@]}") || result=$?
    # 差分の元となるスナップショットがリモートに存在する
    if [ "$result" = "0" ]; then

      echo "Transfer a differential snapshot to the remote."
      # 差分スナップショットを転送する
      zfs send -I ${base_snapshot} ${LOCAL_SNAPSHOTS[-1]} | ssh ${REMOTE_HOST} zfs recv ${REMOTE_POOL}/${DATASET}
      echo "Transfer complete."

    # リモートとの整合性がとれない場合
    else

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

  fi

  if [ ${#LOCAL_SNAPSHOTS[@]} -gt ${MAX_SNAPSHOTS} ]; then # 最大スナップショット数より多い場合古いスナップショットを削除する

    echo "Clear local old snapshots."
    for LOCAL_SNAPSHOT in "${LOCAL_SNAPSHOTS[@]: 0:$((${#LOCAL_SNAPSHOTS[@]}-${MAX_SNAPSHOTS}))}"; do
      zfs destroy ${LOCAL_SNAPSHOT}
    done

  fi

  if [ ${#REMOTE_SNAPSHOTS[@]} -ge ${MAX_SNAPSHOTS} ]; then # 最大スナップショット数より多い場合古いスナップショットを削除する

    echo "Clear remote old snapshots."
    for REMOTE_SNAPSHOT in "${REMOTE_SNAPSHOTS[@]: 0:$((${#REMOTE_SNAPSHOTS[@]}-${MAX_SNAPSHOTS}))}"; do
      zfs destroy ${REMOTE_SNAPSHOT}
    done

  fi

done
