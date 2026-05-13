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
| Immich Postgres / Nextcloud DB / Nextcloud app | ZFS (Lightsail 追加ディスク `/dev/xvdf` を `pool/` に使用) | `pool/immich/...`, `pool/nextcloud/...` (`terraform/aws/modules/lightsail_instance/README.md` 参照) |
| Immich 写真 / Nextcloud ユーザデータ | S3QL (AWS S3 バックエンド, `module.s3ql`) | `/mnt/s3ql/immich`, `/mnt/s3ql/nextcloud` |

ZFS プール作成・データセット作成は `terraform/aws/modules/lightsail_instance/README.md` 側で手動実施します。s3ql のセットアップ (パッケージ導入・authinfo2 配置・systemd unit / verify timer の生成) は本 playbook (`roles/common/tasks/s3ql.yml`) が冪等に実施します。

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

---

# k3s_cluster (multi-node, 並走) のセットアップ

`k3s_cluster` グループ (`k3s-server` + `k3s-agent-{0,1}`) は新規の 3 ノード k3s クラスタです。旧 `k3s-vps` (シングルノード) と並走させて段階移行する想定で、別 inventory グループ・別 playbook (`setup-k3s-cluster.yml`) で扱います。

## ファイル構成

| パス | 役割 |
| --- | --- |
| `inventory.yml` の `k3s_cluster` ツリー | server / agent ホスト定義。各 host エントリに `k3s_node_labels` を書けば `--node-label` で適用される |
| `group_vars/k3s_cluster/vars.yml` | 平文の共通変数 (k3s channel / TLS SAN / ArgoCD / JuiceFS 設定) |
| `group_vars/k3s_cluster/vault.yml` | 暗号化済み secret (下記の手順で作成) |
| `setup-k3s-cluster.yml` | エントリ playbook |
| `roles/node_facts/` | default NIC / IPv4 / IPv6 prefix を register |
| `roles/node_common/` | hostname 設定 + パッケージ更新 + timezone / swap / logrotate |
| `roles/helm_cli/` | helm + helm-diff plugin |
| `roles/k3s_server/` | k3s server インストール + node-token を `k3s_token` fact に bind |
| `roles/k3s_agent/` | server の node-token (`hostvars['k3s-server'].k3s_token`) と private IP で agent join |
| `roles/cluster_ingress_nginx/` / `cluster_cert_manager/` / `cluster_argocd/` / `cluster_juicefs_csi/` | Helm リリースと付随リソース |
| `roles/cluster_app_secrets/` | アプリ用 namespace (`immich`, `nextcloud`) + 各 `*-secrets` (DB / OIDC / SMTP 等) を vault から投入 |

## 構築フロー

### 1. terraform で AWS 側を apply

```bash
cd ../terraform/aws
terraform apply
```

Lightsail インスタンス x3 (server: medium / agent: xlarge) + JuiceFS 用 Lightsail PostgreSQL + JuiceFS 用 S3 バケット & IAM ユーザが作成されます。userdata は `modules/lightsail_instance/scripts/k3s_node_provisioner.sh` が inline で渡され、SSH 鍵 / cloudflared / tailscale のパッケージインストールまでを行います (k3s 本体は ansible 側で導入)。

### 2. 初回ブートストラップ: 22 を一時開放して tailscale / cloudflared 認証

`terraform/aws/main.tf` の `module "k3s_cluster"` の `ports` 内に、コメントアウト済みの **22/TCP** エントリがある。これをアンコメントして `terraform apply` し、public IPv4 経由で各ノードに SSH 接続する:

```bash
cd ../terraform/aws
# main.tf の 22/TCP ブロックをアンコメントして apply
terraform apply

# 各ノードに SSH (公開鍵は provisioner shell が GitHub から流し込む)
ssh ubuntu@$(terraform output -raw k3s_cluster_server_public_ipv4)
```

server / agent それぞれで以下 2 つの認証を実施:

```bash
# Tailscale: tailnet に join (auth key は Tailscale 管理画面で発行)
sudo tailscale up --authkey=tskey-XXXX

# Cloudflare Tunnel: トンネル token を渡してサービス化
# (token は Cloudflare Zero Trust > Networks > Tunnels で発行)
sudo cloudflared service install <TUNNEL_TOKEN>
```

3 ノード全てで両方が完了したら、`main.tf` の 22/TCP ブロックを **再コメント** して `terraform apply` で port を閉じる。以降の SSH / ansible 接続は Tailscale または Cloudflare Tunnel 経由のみ。

### 3. `group_vars/k3s_cluster/vault.yml` の作成

ansible-vault に登録すべき secret 一覧と取得元:

| キー | 取得元 | 取得コマンド例 |
| --- | --- | --- |
| `vault_juicefs_metaurl` | terraform output から組み立て (PostgreSQL DSN、**パスワード抜き**) | 下記スニペット参照 |
| `vault_juicefs_meta_password` | terraform output (sensitive) | `terraform output -raw juicefs_db_master_password` |
| `vault_juicefs_s3_bucket` | terraform output | `terraform output -raw juicefs_s3_bucket_name` |
| `vault_juicefs_s3_access_key_id` | terraform output | `terraform output -raw juicefs_s3_iam_access_key_id` |
| `vault_juicefs_s3_secret_access_key` | terraform output (sensitive) | `terraform output -raw juicefs_s3_iam_secret_access_key` |
| `vault_cloudflare_token` | Cloudflare ダッシュボード (DNS Edit 権限) | 旧 `host_vars/k3s-vps/vault.yml` からコピー可 |
| `vault_email` | ACME 登録用メールアドレス | 旧 vault からコピー可 |
| `vault_argocd_oidc_issuer` | Cloudflare Zero Trust の OIDC アプリ | 旧 vault からコピー可 |
| `vault_argocd_oidc_client_id` | 同上 | 旧 vault からコピー可 |
| `vault_argocd_oidc_client_secret` | 同上 | 旧 vault からコピー可 |
| `vault_argocd_webhook_github_secret` | GitHub webhook 用シークレット | 旧 vault からコピー可 |
| `vault_immich_postgres_user_password` | Immich Postgres ユーザパスワード | 旧 vault からコピー可 |
| `vault_nextcloud_email_address` | Nextcloud 通知メール from アドレス | 旧 vault からコピー可 |
| `vault_nextcloud_smtp_password` | Nextcloud SMTP パスワード | 旧 vault からコピー可 |
| `vault_nextcloud_admin_user` | Nextcloud 管理者ユーザ名 | 旧 vault からコピー可 |
| `vault_nextcloud_admin_password` | Nextcloud 管理者パスワード | 旧 vault からコピー可 |
| `vault_nextcloud_postgres_password` | Nextcloud Postgres パスワード | 旧 vault からコピー可 |
| `vault_nextcloud_oidc_issuer` | Nextcloud OIDC issuer URL | 旧 vault からコピー可 |
| `vault_nextcloud_oidc_client_id` | Nextcloud OIDC client id | 旧 vault からコピー可 |
| `vault_nextcloud_oidc_client_secret` | Nextcloud OIDC client secret | 旧 vault からコピー可 |

> **`K3S_TOKEN` は vault 登録不要**: k3s server が起動時に `/var/lib/rancher/k3s/server/node-token` を自動生成し、`roles/k3s_server` が slurp で `k3s_token` fact 化、`roles/k3s_agent` が `hostvars['k3s-server'].k3s_token` で参照します。

`vault_juicefs_metaurl` の組み立て例 (terraform/aws ディレクトリで実行)。**パスワードは含めない** こと:

```bash
JF_USER=$(terraform output -raw juicefs_db_master_username)
JF_HOST=$(terraform output -raw juicefs_db_endpoint)
JF_PORT=$(terraform output -raw juicefs_db_port)
echo "postgres://${JF_USER}@${JF_HOST}:${JF_PORT}/juicefs?sslmode=require"
```

パスワード (`vault_juicefs_meta_password`) は `terraform output -raw juicefs_db_master_password` で取得し、JuiceFS CSI secret の `envs` フィールド経由で `META_PASSWORD` 環境変数として注入される (URL エンコード不要、平文 secret に metaurl 全体を埋めない)。

vault ファイル作成:

```bash
cd ../ansible
ansible-vault create group_vars/k3s_cluster/vault.yml
# エディタで上記キーを全部書く:
# ---
# vault_juicefs_metaurl: "postgres://..."
# vault_juicefs_s3_bucket: "..."
# ...
```

`ansible.cfg` の `vault_password_file = vault-pass.sh` 経由で 1Password (`op://Private/ansible-vault/password`) から復号鍵が自動取得されます。

### 4. クラスタ構築

```bash
ansible-playbook setup-k3s-cluster.yml
```

順番:
1. `node_facts` で default NIC / private IPv4 を register
2. `node_common` で hostname / OS 基本設定
3. `k3s_server` で control-plane を起動 → node-token を fact 化
4. `k3s_agent` が server private IP + token で join
5. `cluster_ingress_nginx` / `cluster_cert_manager` / `cluster_argocd` / `cluster_juicefs_csi` を helm でデプロイ
6. 全 pod が Ready になるまで待機

### 5. 動作確認

```bash
# kubectl を Tailscale 経由で繋ぐ (server から kubeconfig を取得)
scp k3s-server:.kube/config ~/.kube/config
sed -i '' "s/127.0.0.1/k3s-server/" ~/.kube/config
kubectl --kubeconfig ~/.kube/config get nodes -o wide

# k3s API (6443) が Lightsail public 側で閉じていることを確認
nmap -p 6443 $(cd ../terraform/aws && terraform output -raw k3s_cluster_server_public_ipv4)
# → filtered / closed であるべき (Tailscale 経由のみ)
```

## node label の指定

`inventory.yml` の各 host エントリで `k3s_node_labels` を書くと `--node-label` が付与されます。

```yaml
k3s-agent-0:
  ansible_host: k3s-agent-0
  k3s_node_labels:
    - storage.immich=true
```

未指定なら何も付きません。
