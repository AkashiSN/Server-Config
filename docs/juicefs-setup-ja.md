# JuiceFS セットアップ手順 (Lightsail PostgreSQL + S3)

`terraform/aws/main.tf` で構築した以下のリソースを使い、k3s インスタンス (`module.lightsail_k3s`) 上で JuiceFS をフォーマット・マウントするまでの手順をまとめる。

| 用途 | リソース | Terraform 参照 |
| --- | --- | --- |
| メタデータエンジン | Lightsail PostgreSQL 18 (`micro_2_0`, single-AZ) | `module.lightsail_juicefs_db` |
| マスターパスワード | `random_password` で生成、output に sensitive 公開 | `random_password.juicefs_db` |
| オブジェクトストレージ | S3 バケット (private / SSE-AES256 / versioning + 7d lifecycle) | `module.juicefs_s3` |
| S3 アクセス用 IAM ユーザ | k3s static IPv4 からのみ許可、専用 IAM ユーザ + access key | `module.juicefs_s3` (内部で `./modules/s3` を再利用) |
| At-Rest Encryption | クライアントサイド AES-GCM + RSA。秘密鍵は k3s インスタンス上で管理 (Terraform 管理外) | (本書 Section 3 で生成) |

JuiceFS そのもののインストールや高度な使い方は公式 [JuiceFS Community Docs](https://juicefs.com/docs/community/) を参照。本書は **このリポジトリで作った AWS リソースをどう繋ぐか** に焦点を当てる。

## 前提

- `terraform/aws` 配下で `terraform apply` 済み (Lightsail DB / S3 バケット / IAM ユーザ作成済み)
- k3s インスタンス (`module.lightsail_k3s`) に SSH できる状態
- k3s インスタンスから JuiceFS Community Edition バイナリ (`juicefs`) を実行できる状態 (インストールは公式 [Quick Start Guide](https://juicefs.com/docs/community/quick_start_guide) または `curl -sSL https://d.juicefs.com/install | sh -` を参照)

## 1. 認証情報の取得

`terraform/aws` ディレクトリで以下を実行し、JuiceFS 接続に必要な値をすべて取得する。secret 系は sensitive output のため `-raw` で取り出す。

```bash
cd terraform/aws

# 公開情報 (そのままシェルにエクスポートして良い)
export JFS_DB_HOST=$(terraform output -raw juicefs_db_endpoint)
export JFS_DB_PORT=$(terraform output -raw juicefs_db_port)
export JFS_DB_USER=$(terraform output -raw juicefs_db_master_username)   # "juicefs"
export JFS_DB_NAME=juicefs
export JFS_S3_BUCKET=$(terraform output -raw juicefs_s3_bucket_name)
export JFS_S3_ACCESS_KEY=$(terraform output -raw juicefs_s3_iam_access_key_id)

# 機密情報 (シェル履歴・スクリーンショットに残らないよう注意)
export JFS_DB_PASS=$(terraform output -raw juicefs_db_master_password)
export JFS_S3_SECRET_KEY=$(terraform output -raw juicefs_s3_iam_secret_access_key)
```

これらの値は `terraform/aws/README.md` の Outputs 表にも対応関係を記載している。

## 2. メタデータ DB への接続テスト (任意)

JuiceFS から触る前に、PostgreSQL 接続が成立することを確認しておくとトラブルを切り分けやすい。Lightsail DB は `publicly_accessible=false` で作っているため、**k3s インスタンス上から実行する**。

```bash
# k3s インスタンス上で
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c '\conninfo'
```

`sslmode=require` を付けると AWS が出している自己署名証明書を信頼するだけで接続できる。証明書チェーンまで検証したい場合は `sslmode=verify-full` + AWS RDS の bundled CA を使う (Lightsail でも同じバンドルが流用できる)。

## 3. 暗号化用 RSA 秘密鍵の生成 (At-Rest Encryption)

JuiceFS は AES-GCM + RSA のハイブリッド暗号によるクライアントサイド At-Rest Encryption をサポートする。S3 にアップロードされる **すべてのオブジェクトはアップロード前に JuiceFS 自身が暗号化** するため、AWS S3 側の SSE-AES256 とは独立した二重防御になる。本書ではこの暗号化を **必ず有効化する** 前提で進める。

### 仕組み

- ファイルシステムごとに 1 つの **RSA 秘密鍵** (パスフレーズ保護、PEM 形式) を生成し、`juicefs format` 時に登録する
- 各オブジェクトごとにランダムな AES-256 データ鍵が生成され、本体は AES-GCM、データ鍵は RSA 公開鍵で暗号化されて同じオブジェクトに付与される
- mount 時は `JFS_RSA_PASSPHRASE` 環境変数だけでよい (秘密鍵自体はフォーマット時にメタデータ DB に格納される)
- **format 後に暗号化の有効/無効や鍵を変更することはできない**。鍵またはパスフレーズを失うとファイルシステム全体が復号不能になる

### RSA 秘密鍵とパスフレーズの生成

k3s インスタンス上で以下を実行する。鍵もパスフレーズも k3s インスタンス内に閉じて管理し、Lightsail スナップショット任せにせず別経路でもバックアップを取る。

```bash
# 鍵置き場を root only で用意
sudo install -d -m 0700 -o root -g root /etc/juicefs

# 強いパスフレーズを生成 (44 文字 base64)
sudo bash -c 'openssl rand -base64 32 > /etc/juicefs/jfs-passphrase.txt'
sudo chmod 600 /etc/juicefs/jfs-passphrase.txt

# 2048 bit の RSA 秘密鍵を AES-256-CBC でパスフレーズ暗号化
sudo bash -c '
  JFS_RSA_PASSPHRASE=$(cat /etc/juicefs/jfs-passphrase.txt) \
  openssl genpkey -algorithm RSA -aes256 \
    -pkeyopt rsa_keygen_bits:2048 \
    -pass env:JFS_RSA_PASSPHRASE \
    -out /etc/juicefs/jfs-private.pem
'
sudo chmod 600 /etc/juicefs/jfs-private.pem
```

> **重要 — 鍵紛失=データ消失**
> `/etc/juicefs/jfs-private.pem` と `/etc/juicefs/jfs-passphrase.txt` の両方を失うとファイルシステム全体が復号不能になる。Lightsail インスタンスのスナップショット任せにせず、**別ホスト or AWS Secrets Manager or 1Password** などにオフサイトコピーを取り、定期的に復号テストを行うこと。

### バックアップ例 (任意)

```bash
# 鍵 + パスフレーズを 1 ファイルにまとめて Secrets Manager に格納する例
sudo tar czf - /etc/juicefs/jfs-private.pem /etc/juicefs/jfs-passphrase.txt \
  | base64 \
  | aws secretsmanager create-secret \
      --region ap-northeast-1 \
      --name juicefs/encryption-bundle \
      --secret-string file:///dev/stdin
```

(本リポジトリでは Secrets Manager 用の Terraform リソースは現時点で管理していないため、上記は手動運用扱い)

### アルゴリズム選択 (`--encrypt-algo`)

JuiceFS は 2 つの AEAD 暗号アルゴリズムをサポートする。セキュリティ強度はどちらも 256 bit AEAD で同等のため、**判断軸は CPU 上での性能**。

| アルゴリズム | 想定環境 | 性能の目安 |
| --- | --- | --- |
| `aes256gcm-rsa` (default) | AES-NI (x86_64) / ARM Crypto Extensions が効く CPU | 5–7 GB/s 級 |
| `chacha20-rsa` | AES アクセラレータ非対応 CPU (古い ARM / 組込み / 一部の VM) | ソフト実装で AES より速い |

ChaCha20-Poly1305 はそもそも「モバイル / 旧 ARM で AES が遅すぎる」問題への対処として広まった経緯があり、AES-NI が効く x86 サーバ環境では AES-256-GCM が圧倒的に高速。

**本リポジトリの選択**: `module.lightsail_k3s` の `bundle_id = "xlarge_3_0"` は Lightsail の x86_64 第 3 世代プラン (Intel Xeon または AMD EPYC、いずれも AES-NI 対応) のため `aes256gcm-rsa` を採用する。Go (JuiceFS の実装言語) の `crypto/aes` は AES-NI を自動利用するので、追加チューニングは不要。

apply 後にインスタンス上で AES-NI が露出しているか確認:

```bash
grep -m1 -o 'aes' /proc/cpuinfo
# "aes" が表示されれば AES-NI 有効 → aes256gcm-rsa を採用
# 何も表示されなければ chacha20-rsa を選ぶ
```

将来 ARM 系 Lightsail プラン (Graviton ベース等) に移行する場合は再確認すること。なお `--encrypt-algo` は **format 時に固定** され後から変更できないため (Section 7 のファイルシステム再作成が必要)、format 直前に上記コマンドで確認するのが望ましい。

## 4. ファイルシステムの初期化 (`juicefs format`)

メタデータ DB に空のテーブル群を作成し、S3 バケットと紐付ける。**1 つのファイルシステムにつき 1 度だけ** 実行する。**Section 3 で生成した RSA 秘密鍵を `--encrypt-rsa-key` で渡し、暗号化を有効化する**。

```bash
# 暗号化鍵のパスフレーズを環境変数に展開 (シェル履歴に直接書かないこと)
export JFS_RSA_PASSPHRASE=$(sudo cat /etc/juicefs/jfs-passphrase.txt)

META_PASSWORD="$JFS_DB_PASS" \
JFS_RSA_PASSPHRASE="$JFS_RSA_PASSPHRASE" \
sudo -E juicefs format \
  --storage s3 \
  --bucket "https://${JFS_S3_BUCKET}.s3.ap-northeast-1.amazonaws.com" \
  --access-key "$JFS_S3_ACCESS_KEY" \
  --secret-key "$JFS_S3_SECRET_KEY" \
  --encrypt-rsa-key /etc/juicefs/jfs-private.pem \
  --encrypt-algo aes256gcm-rsa \
  "postgres://${JFS_DB_USER}@${JFS_DB_HOST}:${JFS_DB_PORT}/${JFS_DB_NAME}?sslmode=require" \
  myjfs
```

ポイント:

- **`META_PASSWORD` 環境変数** を使って DB パスワードを渡す。URL に `:password@` で埋め込まないこと。プロセス一覧 (`ps`) や履歴に残るリスクを避けるため。
- **`JFS_RSA_PASSPHRASE` 環境変数** を使って暗号化鍵のパスフレーズを渡す。`--encrypt-rsa-key` の値を読み出すために必要。`sudo -E` で環境変数を引き継ぐ点に注意。
- **`--encrypt-algo aes256gcm-rsa`** — Lightsail x86_64 + AES-NI 前提の選択。判断根拠と確認コマンドは Section 3 「アルゴリズム選択」を参照。format 時固定で後から変更不可。
- **メタデータ URL の `sslmode=require`** を付ける。Lightsail PostgreSQL は SSL 強制ではないが、付けておくと万一公開設定に変わっても暗号化通信になる。
- **`--bucket` は仮想ホスト形式の URL** を使う (`https://<bucket>.s3.<region>.amazonaws.com`)。AWS S3 では path-style がレガシー扱いのため。
- 末尾の `myjfs` は **ファイルシステム名**。マウント時にも参照されるため、覚えやすい名前を付ける (本リポジトリの命名と揃えるなら `juicefs` でも可)。

成功すると以下のようなログが出て、PostgreSQL 側に約 14 個のテーブルが作成される。`Encrypted: true` の表示があるか必ず確認する。

```
<INFO>: Volume is formatted as ...
<INFO>: Encrypted: true (algorithm: aes256gcm-rsa)
```

確認:

```bash
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c '\dt'

# format 結果を再確認
META_PASSWORD="$JFS_DB_PASS" juicefs status \
  "postgres://${JFS_DB_USER}@${JFS_DB_HOST}:${JFS_DB_PORT}/${JFS_DB_NAME}?sslmode=require" \
  | grep -i encrypt
```

## 5. マウント (`juicefs mount`)

mount 時は **秘密鍵のパスは指定しない** (フォーマット時にメタデータ DB に保存済みのため)。`JFS_RSA_PASSPHRASE` 環境変数だけ渡せば JuiceFS が DB から鍵を取得し、パスフレーズで復号して使う。

```bash
sudo mkdir -p /mnt/juicefs

export JFS_RSA_PASSPHRASE=$(sudo cat /etc/juicefs/jfs-passphrase.txt)

META_PASSWORD="$JFS_DB_PASS" \
JFS_RSA_PASSPHRASE="$JFS_RSA_PASSPHRASE" \
sudo -E juicefs mount \
  --background \
  "postgres://${JFS_DB_USER}@${JFS_DB_HOST}:${JFS_DB_PORT}/${JFS_DB_NAME}?sslmode=require" \
  /mnt/juicefs
```

`--background` で daemon 化される。`df -h /mnt/juicefs` でマウント済みであることを確認する。`juicefs mount` は `juicefs format` と違い、**全クライアントで都度実行する** (k3s ノードが増えたらそれぞれで mount する。秘密鍵パスフレーズも各ノードに配布が必要)。

systemd 化する場合は公式 [Mount JuiceFS at boot](https://juicefs.com/docs/community/administration/mount_at_boot) を参照。以下のような `EnvironmentFile=` を 0600 で配置するのが定石:

```ini
# /etc/juicefs/myjfs.env  (mode 0600, owner root)
META_PASSWORD=...
JFS_RSA_PASSPHRASE=...
```

### k3s から使う場合

PVC として参照する場合は [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction) を入れるのが王道。本リポジトリでは Helm/manifests の追加は本書の範囲外とするが、要点だけ:

- CSI Driver のインストールは `helm install juicefs-csi-driver` または manifests
- `Secret` に以下を入れる:
  - `metaurl` (`postgres://...?sslmode=require`)
  - `access-key`, `secret-key`, `bucket`
  - `envs`: `{"META_PASSWORD": "...", "JFS_RSA_PASSPHRASE": "..."}` (CSI Driver が mount プロセスに渡す)
- `metaurl` 内のパスワードは URL エンコードして埋め込むか、Secret 内の別フィールドに置いて CSI Driver の `format-options` から渡す
- 暗号化済みファイルシステムを mount する場合、Secret に `JFS_RSA_PASSPHRASE` を必ず含める。**秘密鍵そのものはメタデータ DB 側にあるため CSI Secret には不要**

詳細は [Use JuiceFS in Kubernetes](https://juicefs.com/docs/csi/getting_started) と [JuiceFS CSI: Encrypt Data In Transit and At Rest](https://juicefs.com/docs/csi/guide/encryption) を参照。

## 6. パスワードローテーション運用

Terraform の仕様上、`master_password` の初回値は tfstate に平文で残る。`module.lightsail_juicefs_db` は `lifecycle.ignore_changes = [master_password]` を持つため、**初回 apply 後に Lightsail コンソール / CLI で別パスワードにローテートしても Terraform 側の差分にはならない**。推奨フロー:

1. `terraform apply` で初回パスワードを設定 (`random_password.juicefs_db.result`)
2. 上記の Outputs から取得して `juicefs format` を実行 (一度きり)
3. AWS CLI で別パスワードにローテート

```bash
NEW_PASS=$(openssl rand -base64 24 | tr -d '/+=@" ')   # Lightsail 禁止文字を除去
aws lightsail update-relational-database \
  --region ap-northeast-1 \
  --relational-database-name su-nishi-juicefs \
  --master-user-password "$NEW_PASS" \
  --apply-immediately
```

4. `juicefs mount` 実行側 (k3s ノード / systemd unit / Kubernetes Secret) のパスワードを `$NEW_PASS` で更新
5. 以降のローテートはコンソール / CLI 側のみで完結。Terraform は触らない (state 上の値は使われていない過去のパスワードになる)

なお **暗号化用 RSA 秘密鍵そのもの** は `juicefs format` 時点でメタデータ DB に登録された後は変更できない (公式仕様)。鍵をローテートしたい場合はファイルシステムを作り直す (Section 7) しかなく、データを別ファイルシステムにコピーしてから旧 FS を破棄する手順が必要になる。**運用開始前に強いパスフレーズを設定し、以後は鍵自体ではなくパスフレーズを保護する** という設計にすること。

## 7. ファイルシステムを作り直す場合

JuiceFS は **メタデータ DB を空にすればファイルシステムを破棄したのと同義**。S3 バケットに残ったオブジェクトは孤児になるので、明示的に削除する。

```bash
# メタデータをクリア
PGPASSWORD="$JFS_DB_PASS" psql \
  "host=$JFS_DB_HOST port=$JFS_DB_PORT user=$JFS_DB_USER dbname=$JFS_DB_NAME sslmode=require" \
  -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'

# S3 バケットを空にする (バージョニング有効なので --include-versions が必要なツールもある)
aws s3 rm "s3://${JFS_S3_BUCKET}" --recursive
```

その後 `juicefs format` を再実行する (Section 4)。鍵もローテートしたい場合は Section 3 から作り直す。なお S3 バケット側のバージョニング + 7 日 lifecycle のため、削除直後は noncurrent version として 7 日残る (これは `module.juicefs_s3` のデフォルト)。

## 制約と注意点

- **single-AZ**: `bundle_id = "micro_2_0"` は single-AZ 構成。AZ 障害でメタデータ DB が消えると JuiceFS のファイルシステムも消える (S3 のオブジェクトは生きていてもメタデータがないので参照不能)。重要データを乗せる場合は `micro_ha_2_0` への移行 (Multi-AZ、約 2 倍コスト) を検討する。なお `bundle_id` の変更は destroy + create を伴うので、本番運用前に `skip_final_snapshot=false` + `final_snapshot_name` を設定してから移行すること。
- **拡張機能不可**: Lightsail マネージド DB は `shared_preload_libraries` を変更できないので、`pgvector` などの追加 extension は使えない。JuiceFS のメタデータエンジンは追加 extension を要求しないため問題はないが、同 DB を別用途に流用するのは避けた方がよい。
- **接続元の制約**: `publicly_accessible=false` で運用しているため、Lightsail アカウント外からは接続できない。同アカウントの他リージョンや別 VPC からの接続も不可。k3s ノード上で `juicefs mount` する以外の経路 (例: ローカルからの調査) を使う場合は、SSH ポートフォワードを使う。
- **S3 アクセス IP 制限**: `module.juicefs_s3` の IAM ポリシーは `module.lightsail_k3s.public_ipv4` からのみ許可。k3s インスタンスを作り直して static IP が変わると IAM ポリシーは Terraform で自動追従するが、IP が変わっている間 (apply 完了まで) は JuiceFS が S3 にアクセスできず動作不能になる。インスタンス再作成時は `juicefs mount` を停止してから実施するのが安全。
- **メタデータ消失=FS 消失**: 上述のとおり致命的。Lightsail 自動バックアップ (7 日保持、`backup_retention_enabled = true` がデフォルト有効) に加え、定期スナップショットの取得や、JuiceFS の `juicefs dump` によるメタデータエクスポートを併用するのが望ましい (公式 [Metadata Backup](https://juicefs.com/docs/community/administration/metadata_dump_load) 参照)。
- **暗号化鍵 / パスフレーズ消失=データ消失**: `juicefs format` 時に登録した RSA 秘密鍵 (パスフレーズ込み) を失うと、メタデータ DB と S3 オブジェクトが両方無事でも復号不能。`/etc/juicefs/jfs-private.pem` と `/etc/juicefs/jfs-passphrase.txt` は Lightsail インスタンス外 (Secrets Manager / 1Password / 別ホスト) にもバックアップを取り、定期的に「別環境にリストアして復号できるか」を検証する。
- **暗号化設定の変更不可**: `--encrypt-rsa-key` / `--encrypt-algo` は format 時の選択が固定される。後から暗号化方式を切り替えたり鍵をローテートする場合は、Section 7 でファイルシステムを作り直し、データを別 FS 経由でコピーする必要がある。
- **CPU 負荷とパフォーマンス**: クライアントサイド AES-GCM 暗号化は CPU を消費する。`micro_*` クラスの k3s インスタンスでは大量の小ファイル書き込み時にスループットが頭打ちになる可能性がある。本番採用前に `juicefs bench /mnt/juicefs` で実測しておくこと。

## 参考

- 本リポジトリ
  - [`terraform/aws/README.md`](../terraform/aws/README.md)
  - [`terraform/aws/modules/lightsail_database/README.md`](../terraform/aws/modules/lightsail_database/README.md)
  - [`terraform/aws/modules/s3/README.md`](../terraform/aws/modules/s3/README.md)
- JuiceFS 公式
  - [Quick Start Guide](https://juicefs.com/docs/community/quick_start_guide)
  - [Set Up Metadata Engine — PostgreSQL](https://juicefs.com/docs/community/databases_for_metadata#postgresql)
  - [Set Up Object Storage — S3](https://juicefs.com/docs/community/how_to_set_up_object_storage#amazon-s3)
  - [Use JuiceFS on AWS](https://juicefs.com/docs/community/clouds/aws)
  - [Encryption At Rest](https://juicefs.com/docs/community/security/encryption) — `--encrypt-rsa-key` / `JFS_RSA_PASSPHRASE` 仕様の一次情報
  - [Metadata Backup and Recovery](https://juicefs.com/docs/community/administration/metadata_dump_load)
  - [JuiceFS CSI Driver](https://juicefs.com/docs/csi/introduction)
  - [JuiceFS CSI: Encrypt Data](https://juicefs.com/docs/csi/guide/encryption)
