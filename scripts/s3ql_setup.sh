#!/usr/bin/env bash
#
# Provision s3ql on a fresh Debian/Ubuntu host.
# Mirrors ansible/roles/common/tasks/s3ql.yml for the k3s-vps filesystems
# (immich / nextcloud). Run as root.
#
# Required environment variables:
#   S3QL_ACCESS_KEY_ID
#   S3QL_SECRET_ACCESS_KEY
#   S3QL_BUCKET
#   S3QL_FS_PASSPHRASE_IMMICH
#   S3QL_FS_PASSPHRASE_NEXTCLOUD
#
# Optional:
#   S3QL_VERSION  (default: 6.0.0)
#   S3QL_REGION   (default: ap-northeast-1)

set -euo pipefail

S3QL_VERSION="${S3QL_VERSION:-6.0.0}"
S3QL_REGION="${S3QL_REGION:-ap-northeast-1}"

: "${S3QL_ACCESS_KEY_ID:?must be set}"
: "${S3QL_SECRET_ACCESS_KEY:?must be set}"
: "${S3QL_BUCKET:?must be set}"
: "${S3QL_FS_PASSPHRASE_IMMICH:?must be set}"
: "${S3QL_FS_PASSPHRASE_NEXTCLOUD:?must be set}"

if [[ $EUID -ne 0 ]]; then
    echo "must run as root" >&2
    exit 1
fi

# Filesystem definitions (parallel arrays — keep indices aligned).
FS_NAMES=(immich nextcloud)
FS_DESCRIPTIONS=("Immich photos" "Nextcloud data")
FS_MOUNT_POINTS=(/mnt/s3ql/immich-photos /mnt/s3ql/nextcloud-data)
FS_PASSPHRASES=("${S3QL_FS_PASSPHRASE_IMMICH}" "${S3QL_FS_PASSPHRASE_NEXTCLOUD}")

# Defaults from ansible/roles/common/vars/main.yml
S3QL_DEFAULT_CACHE_SIZE=83886080
S3QL_DEFAULT_MAX_THREADS=2
S3QL_DEFAULT_METADATA_BACKUP_INTERVAL=3600
S3QL_DEFAULT_COMPRESS=zlib-1

storage_url_for() {
    local name="$1"
    echo "s3://${S3QL_REGION}/${S3QL_BUCKET}/${name}/"
}

wait_apt() {
    local lock
    for lock in /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend; do
        if [[ -f "$lock" ]]; then
            while fuser "$lock" >/dev/null 2>&1; do
                sleep 5
            done
        fi
    done
    apt-get "$@"
}

# Write a file only when the content differs. Echoes "changed" or "unchanged".
write_file() {
    local dest="$1" mode="$2" content="$3"
    if [[ -f "$dest" ]] && [[ "$(cat "$dest")" == "$content" ]]; then
        chmod "$mode" "$dest"
        echo unchanged
        return
    fi
    install -o root -g root -m "$mode" /dev/null "$dest"
    printf '%s' "$content" >"$dest"
    echo changed
}

#
# 1. Install build/runtime dependencies
#
export DEBIAN_FRONTEND=noninteractive
wait_apt update
wait_apt install -y \
    psmisc fuse3 libfuse3-dev libsqlite3-dev python3-dev pipx pkg-config

#
# 2. Raise file descriptor limits
#
install -d -o root -g root -m 0755 /etc/systemd/system.conf.d

systemd_nofile_state=$(write_file /etc/systemd/system.conf.d/10-nofile.conf 0644 \
'[Manager]
DefaultLimitNOFILE=131072:524288
')

write_file /etc/security/limits.d/99-s3ql.conf 0644 \
'*       soft    nofile    131072
*       hard    nofile    524288
root    soft    nofile    131072
root    hard    nofile    524288
' >/dev/null

sysctl_state=$(write_file /etc/sysctl.d/99-s3ql.conf 0644 \
'fs.file-max = 2097152
')

if [[ "$sysctl_state" == "changed" ]]; then
    sysctl --system
fi
if [[ "$systemd_nofile_state" == "changed" ]]; then
    systemctl daemon-reexec
fi

#
# 3. Install s3ql via pipx (skip if /etc/s3ql/version already matches)
#
need_install=1
if [[ -f /etc/s3ql/version ]] && [[ "$(tr -d '[:space:]' </etc/s3ql/version)" == "$S3QL_VERSION" ]]; then
    need_install=0
fi

if [[ $need_install -eq 1 ]]; then
    tarball="/tmp/s3ql-${S3QL_VERSION}.tar.gz"
    srcdir="/tmp/s3ql-${S3QL_VERSION}"
    if [[ ! -f "$tarball" ]]; then
        curl -fsSL --retry 10 \
            "https://github.com/s3ql/s3ql/releases/download/s3ql-${S3QL_VERSION}/s3ql-${S3QL_VERSION}.tar.gz" \
            -o "$tarball"
        chmod 0644 "$tarball"
    fi
    if [[ ! -f "$srcdir/pyproject.toml" ]]; then
        tar -xzf "$tarball" -C /tmp
    fi
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin \
    PIPX_MAN_DIR=/usr/local/share/man \
        pipx install --force "$srcdir"

    install -d -o root -g root -m 0755 /etc/s3ql
    printf '%s\n' "$S3QL_VERSION" >/etc/s3ql/version
    chmod 0644 /etc/s3ql/version
fi

#
# 4. Common runtime dirs
#
install -d -o root -g root -m 0700 /root/.s3ql
install -d -o root -g root -m 0700 /var/cache/s3ql

#
# 5. Per-filesystem dirs + mount points
#
for i in "${!FS_NAMES[@]}"; do
    install -d -o root -g root -m 0700 "/var/cache/s3ql/${FS_NAMES[$i]}"
    install -d -o root -g root -m 0700 "${FS_MOUNT_POINTS[$i]}"
done

#
# 6. authinfo2
#
{
    printf '[s3]\n'
    printf 'storage-url: s3://\n'
    printf 'backend-login: %s\n' "$S3QL_ACCESS_KEY_ID"
    printf 'backend-password: %s\n' "$S3QL_SECRET_ACCESS_KEY"
    for i in "${!FS_NAMES[@]}"; do
        printf '\n[%s]\n' "${FS_NAMES[$i]}"
        printf 'storage-url: %s\n' "$(storage_url_for "${FS_NAMES[$i]}")"
        printf 'fs-passphrase: %s\n' "${FS_PASSPHRASES[$i]}"
    done
} >/root/.s3ql/authinfo2
chown root:root /root/.s3ql/authinfo2
chmod 0600 /root/.s3ql/authinfo2

#
# 7. wait-and-umount wrapper (used by ExecStop)
#
cat >/usr/local/sbin/s3ql-wait-and-umount <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mp="${1:?mountpoint required}"
warned=0
while fuser -m "$mp" >/dev/null 2>&1; do
    if [[ $warned -eq 0 ]]; then
        echo "s3ql: $mp is still in use, waiting for release..." >&2
        fuser -mv "$mp" 2>&1 | logger -t s3ql-stop || true
        warned=1
    fi
    sleep 5
done
if [[ $warned -eq 1 ]]; then
    echo "s3ql: $mp released, proceeding to umount" >&2
fi
exec /usr/local/bin/umount.s3ql "$mp"
EOF
chown root:root /usr/local/sbin/s3ql-wait-and-umount
chmod 0755 /usr/local/sbin/s3ql-wait-and-umount

#
# 8. systemd units
#
for i in "${!FS_NAMES[@]}"; do
    name="${FS_NAMES[$i]}"
    description="${FS_DESCRIPTIONS[$i]}"
    mount_point="${FS_MOUNT_POINTS[$i]}"
    storage_url="$(storage_url_for "$name")"
    cache_size="$S3QL_DEFAULT_CACHE_SIZE"
    max_threads="$S3QL_DEFAULT_MAX_THREADS"
    backup_interval="$S3QL_DEFAULT_METADATA_BACKUP_INTERVAL"
    compress="$S3QL_DEFAULT_COMPRESS"

    cat >"/etc/systemd/system/s3ql-${name}.service" <<EOF
[Unit]
Description=S3QL mount for ${description}
After=network-online.target
Wants=network-online.target
Before=k3s.service

[Service]
Type=notify
KillMode=process
TimeoutStartSec=0
TimeoutStopSec=infinity
LimitNOFILE=131072
ExecStartPre=/usr/local/bin/fsck.s3ql --batch --authfile /root/.s3ql/authinfo2 ${storage_url}
ExecStart=/usr/local/bin/mount.s3ql --allow-other --authfile /root/.s3ql/authinfo2 --cachedir /var/cache/s3ql/${name} --cachesize ${cache_size} --metadata-backup-interval ${backup_interval} --systemd --max-threads ${max_threads} --compress ${compress} --keep-cache --log none ${storage_url} ${mount_point}
ExecStop=/usr/local/sbin/s3ql-wait-and-umount ${mount_point}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "/etc/systemd/system/s3ql-${name}.service"

    cat >"/etc/systemd/system/s3ql-verify-${name}.service" <<EOF
[Unit]
Description=Verify S3QL backend integrity for ${description}
Conflicts=s3ql-${name}.service
After=s3ql-${name}.service

[Service]
Type=oneshot
TimeoutStartSec=infinity
ExecStart=/usr/local/bin/s3ql_verify --authfile /root/.s3ql/authinfo2 --missing-file /var/log/s3ql-verify-${name}-missing.txt --corrupted-file /var/log/s3ql-verify-${name}-corrupted.txt ${storage_url}
ExecStopPost=/bin/systemctl start s3ql-${name}.service
EOF
    chmod 0644 "/etc/systemd/system/s3ql-verify-${name}.service"
done

#
# 9. Enable + start mount services
#   Ansible only starts when /etc/s3ql/version already matched at the top of
#   the run (i.e. nothing was reinstalled this run). Replicate that.
#
systemctl daemon-reload
for name in "${FS_NAMES[@]}"; do
    systemctl enable "s3ql-${name}.service"
done

if [[ $need_install -eq 0 ]]; then
    for name in "${FS_NAMES[@]}"; do
        systemctl start "s3ql-${name}.service"
    done
else
    echo "s3ql ${S3QL_VERSION} freshly installed; not auto-starting mount services." >&2
    echo "Create the filesystems with mkfs.s3ql, then start them manually:" >&2
    for name in "${FS_NAMES[@]}"; do
        echo "  systemctl start s3ql-${name}.service" >&2
    done
fi
