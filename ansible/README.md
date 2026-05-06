# Ansible

`k3s-vps` ホスト (AWS Lightsail / Ubuntu 24.04) を k3s シングルノードクラスタとしてプロビジョニングします。

## Prerequisites

- Ubuntu 24.04 のターゲットホスト (`k3s-lightsail.akashisn.info`) に SSH で到達できること
- ローカルに `ansible` / `ansible-playbook` がインストール済みであること
- [1Password CLI (`op`)](https://developer.1password.com/docs/cli/) にサインイン済みで、`op://Private/ansible-vault/password` および `op://Private/ansible-vault/vault.yml` にアクセスできること
- Ansible collections のインストール

  ```bash
  ansible-galaxy collection install -r requirements.yml
  ```

## Layout

| パス | 役割 |
| --- | --- |
| `ansible.cfg` | inventory / vault パスワードファイル / python interpreter (3.12) の設定 |
| `inventory.yml` | `k3s-vps` ホスト定義 (`ansible_host: k3s-lightsail.akashisn.info`) |
| `vault-pass.sh` | 1Password から vault パスワードを読み取るスクリプト (`ansible.cfg` から参照) |
| `requirements.yml` | 必要な Ansible collections (`community.general`, `kubernetes.core`) |
| `setup-k3s-vps.yml` | `variable` → `common` → `cluster` ロールを順に実行する playbook (`k8s_major_version: 1.35`, `target_env: production`) |
| `host_vars/k3s-vps/vars.yml` | ドメイン / k3s ノードラベル / oauth2-proxy / argo-cd / s3ql 設定などの変数 |
| `host_vars/k3s-vps/vault.yml` | 暗号化済み秘密値 (`make credential` で取得) |
| `roles/variable/` | 共通変数の収集 (default interface, node IP, external IP, IPv6 prefix など) |
| `roles/common/` | OS 基本設定: パッケージ更新, timezone, swap, logrotate, kernel sysctl, helm, **s3ql (pipx + systemd mount unit + 手動 verify サービス + `s3ql-wait-and-umount` ラッパー)**, k3s server インストール |
| `roles/cluster/` | クラスタ内 Helm リリース: ingress-nginx, cert-manager, oauth2-proxy, argo-cd, secrets, storage-class |

## Usage

### 1. Vault credential 取得

1Password から `host_vars/k3s-vps/vault.yml` をローカルに取得します。

```bash
make credential
```

### 2. プロビジョニング実行

```bash
make k3s-vps
```

内部で `ansible-playbook setup-k3s-vps.yml` を実行します。`vault-pass.sh` 経由で vault が復号されるため、事前に `op` のサインインが必要です。

### 3. ローカル credential の掃除

```bash
make clean
```

`host_vars/k3s-vps/vault.yml` を削除します（リポジトリ外に漏らさないため）。

## ストレージ構成の概要

`k3s-vps` 上のデータは用途別に 2 系統で保持されます。

| 用途 | バックエンド | マウント先 / 保存先 |
| --- | --- | --- |
| Immich Postgres / Nextcloud DB / Nextcloud app | ZFS (Lightsail 追加ディスク `/dev/xvdf` を `pool/` に使用) | `pool/immich/...`, `pool/nextcloud/...` (`terraform/aws/modules/lightsail/README.md` 参照) |
| Immich 写真 / Nextcloud ユーザデータ | S3QL (AWS S3 バックエンド, `module.s3ql`) | `/mnt/s3ql/immich`, `/mnt/s3ql/nextcloud` |

ZFS プール作成・データセット作成は `terraform/aws/modules/lightsail/README.md` 側で手動実施します。s3ql のセットアップ (パッケージ導入・authinfo2 配置・systemd unit / verify timer の生成) は本 playbook (`roles/common/tasks/s3ql.yml`) が冪等に実施します。

## s3ql セットアップ

s3ql は `pipx` 経由でソース tarball (`s3ql_version`, デフォルト `6.0.0`) からインストールされ、`/etc/s3ql/version` でバージョンを管理します。`host_vars/k3s-vps/vars.yml` の `s3ql_filesystems` 配列に従って、ファイルシステムごとに以下が生成されます。

- `/etc/systemd/system/s3ql-<name>.service` (mount unit。`ExecStartPre` で毎回 `fsck.s3ql --batch` が走る。`ExecStop` は `s3ql-wait-and-umount` ラッパー経由)
- `/etc/systemd/system/s3ql-verify-<name>.service` (oneshot。**自動実行はせず手動でのみ叩く**。`Conflicts=s3ql-<name>.service` でマウントを停止し、終了後 `ExecStopPost` で再 mount する)
- `/usr/local/sbin/s3ql-wait-and-umount` (mount unit と共通。マウントポイントが `fuser -m` で掴まれている間は `umount.s3ql` を呼ばずに待機する)
- `/var/cache/s3ql/<name>/` (キャッシュ)
- `<mount_point>` (例: `/mnt/s3ql/immich`, `/mnt/s3ql/nextcloud`)

現状の `s3ql_filesystems`:

| name | mount_point |
| --- | --- |
| immich | `/mnt/s3ql/immich` |
| nextcloud | `/mnt/s3ql/nextcloud` |

S3 backend のデータ整合性チェック (`s3ql_verify`) はマウント中の filesystem を一旦停止する重い処理であり、AWS S3 + SSE-S3 の耐久性に依拠して定期実行は行いません。必要なときだけ手動で起動します。

```bash
# verify を手動実行 (該当マウントは自動的に停止 → 完了後に自動再 mount)
sudo systemctl start s3ql-verify-immich.service
sudo journalctl -u s3ql-verify-immich.service -f
```

### 停止 / アンマウント挙動

`systemctl stop s3ql-<name>.service` と shutdown 時の自動停止はいずれも `ExecStop=/usr/local/sbin/s3ql-wait-and-umount <mount_point>` を経由します。マウントポイントを `cwd` 等で掴んでいるプロセスがある間は `umount.s3ql` を呼ばずに 5 秒間隔でポーリングし、解放されてから `umount.s3ql` に exec します。`TimeoutStopSec=infinity` のため systemd 側は打ち切りません(=cache flush 前に SIGTERM される事故を防ぐ)。

```bash
sudo journalctl -t s3ql-stop -f          # 待機中のラッパーが出すログ
sudo fuser -mv /mnt/s3ql/immich          # 掴んでいるプロセスを確認
```

掴んでいる側を `cd /` で移動 (tmux 内シェルの場合は各 pane で実施) するか、対象プロセスを終了させると次のポーリングでアンマウントが進みます。

> 注: 何かが永久に解放しない場合 shutdown が無限に止まり得ます。最終的にハードウェアウォッチドッグ (distro 既定の `ShutdownWatchdogSec`) で再起動されるか、手動電源 off になります。

### dirty unmount からの復旧

マウント中の `mount.s3ql` が SIGKILL されるなどしてキャッシュ未アップロードのまま落ちた場合、バックエンドのメタデータに「mounted elsewhere」フラグが残り、次回起動で `ExecStartPre` の `fsck.s3ql --batch` が `status=41` で失敗します。一度だけ手動で対話モードの fsck を回して lock を解除します。

```bash
sudo /usr/local/bin/fsck.s3ql \
  --authfile /root/.s3ql/authinfo2 \
  s3://ap-northeast-1/<bucket>/immich/
# プロンプトに対し完全一致で入力:
#   continue, I know what I am doing

sudo systemctl reset-failed s3ql-immich.service
sudo systemctl start s3ql-immich.service
```

最後のメタデータアップロード(unit 既定 `--metadata-backup-interval 3600` = 最大 1 時間前)以降の変更は失われる可能性があります。fsck が拾えたファイル本体は `<mount_point>/lost+found/` に救出されることがあります。

### 1. 1Password → vault.yml に登録

以下のキーを `host_vars/k3s-vps/vault.yml` に追加します (1Password 側にも反映)。

| キー | 値 |
| --- | --- |
| `vault_s3ql_access_key_id` | s3ql 用 IAM アクセスキー (`terraform output s3ql_iam_access_key_id`) |
| `vault_s3ql_secret_access_key` | s3ql 用 IAM シークレットキー (`terraform output -raw s3ql_iam_secret_access_key`) |
| `vault_s3ql_bucket` | バケット名 (`terraform output s3ql_bucket_name`) |
| `vault_immich_s3ql_fs_passphrase` | immich ファイルシステム用に生成したパスフレーズ |
| `vault_nextcloud_s3ql_fs_passphrase` | nextcloud ファイルシステム用に生成したパスフレーズ |

storage URL は `vars.yml` 側で `s3://<region>/<bucket>/<name>/` の形式に組み立てられます (`s3ql_region: ap-northeast-1`)。

### 2. 初回のみ `mkfs.s3ql` を手動実行

ansible は `mkfs.s3ql` を実行しません。初回 (および s3ql バージョンアップ直後) は mount サービスの `started` ステートをスキップするため、各ファイルシステムについて手動で mkfs → 起動します。

```bash
# 一度 ansible を流して s3ql をインストールし、authinfo2 と systemd unit/timer を配置する
make k3s-vps

# k3s-vps ノードに SSH して、各ファイルシステムごとに mkfs (初回 1 回だけ)
sudo /usr/local/bin/mkfs.s3ql --authfile /root/.s3ql/authinfo2 \
    s3://ap-northeast-1/<bucket>/immich/
sudo /usr/local/bin/mkfs.s3ql --authfile /root/.s3ql/authinfo2 \
    s3://ap-northeast-1/<bucket>/nextcloud/

sudo systemctl start s3ql-immich.service s3ql-nextcloud.service
```

以降は `make k3s-vps` を流すだけで `s3ql-<name>.service` が冪等に維持されます。

## Notes

- Kubernetes 上のアプリ (dns / nextcloud / immich など) は [`../kubernetes/`](../kubernetes/README.md) 側で管理します。
- AWS リソース (Lightsail インスタンス / 追加ディスク / Static IP / s3ql 用 S3 バケット & IAM ユーザ) は [`../terraform/aws/`](../terraform/aws/) で管理します。
- Ansible 管理外のホストへ s3ql 構成だけ単独で入れたい場合は [`../scripts/s3ql_setup.sh`](../scripts/s3ql_setup.sh) を root で実行できます。`s3ql_filesystems` は immich / nextcloud にハードコードされており、シークレットは環境変数 (`S3QL_ACCESS_KEY_ID` / `S3QL_SECRET_ACCESS_KEY` / `S3QL_BUCKET` / `S3QL_FS_PASSPHRASE_IMMICH` / `S3QL_FS_PASSPHRASE_NEXTCLOUD`) で渡します。スクリプト先頭のコメントを参照してください。
