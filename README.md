# writersbase-tools

VPS上で実行する雑多なユーティリティ。

cronタスク等としてよく行うサーバー管理処理を集めたツール群です。
FreeBSDおよびUbuntu Serverに対応しています。

## セットアップ

```sh
git clone https://github.com/THE-POWERNEWS/writersbase-tools.git
cd writersbase-tools
bundle install
```

## 使い方

### ツールの実行

```sh
bin/wb <ツール名>
```

### ツール一覧の表示

```sh
bin/wb help
```

### cronへのインストール・アンインストール

`config/local.yaml`の`hourly`、`daily`、`weekly`、`monthly`にツール名を設定し、
rakeタスクでcronスクリプトとしてインストールできます。

```sh
rake install    # cronスクリプトをインストール
rake uninstall  # cronスクリプトをアンインストール
```

## ツール

| ツール名 | 説明 |
| --- | --- |
| access_log_compress | 指定日数が経過したログファイルをzstd圧縮します。 |
| help | ツール一覧を表示します。 |
| mastodon_follow | 全ユーザーに指定アカウントを強制フォローさせます。 |
| mastodon_maintenance | Mastodonのメンテナンスコマンドを実行します。 |
| mastodon_media_cleanup | Mastodonの古いメディアファイルを削除します。 |
| mysql_dump | MySQLのダンプファイルを作成します。 |
| mysql_snapshot | MySQLのZFSスナップショットを作成・管理します。 |
| postgresql_dump | PostgreSQLのダンプファイルを作成します。 |
| postgresql_snapshot | PostgreSQLのZFSスナップショットを作成・管理します。 |
| reboot_required | システムに再起動が必要かを判定します。 |
| rsync_backup | rsyncでファイルを外部サーバーにバックアップします。 |
| service_restart | 設定されたサービスを再起動します。 |

## 設定

`config/application.yaml`にデフォルト値が定義されています。
環境固有の設定は`config/local.yaml`を作成し、必要な項目のみ上書きしてください（`application.yaml`を直接編集する必要はありません）。
`config/local.yaml`はGit管理対象外です。

### access_log_compress

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dir | 対象ディレクトリ | /var/log/nginx |
| days | 経過日数 | 1 |

### mysql_dump

| キー | 説明 | デフォルト |
| --- | --- | --- |
| host | 接続先ホスト | 127.0.0.1 |
| user | 接続ユーザー | root |
| password | パスワード | null |
| databases | 対象データベース名の配列 | [] |
| port | ポート番号 | 3306 |
| days | ダンプファイル保管日数 | 7 |
| dest.dir | 出力先ディレクトリ | /var/backups/db |

### mysql_snapshot

| キー | 説明 | デフォルト |
| --- | --- | --- |
| target | 対象ZFSパーティション | zroot/mysql |
| days | スナップショット保管日数 | 3 |
| host | 接続先ホスト | 127.0.0.1 |
| user | 接続ユーザー | root |
| password | パスワード | null |
| port | ポート番号 | 3306 |

### postgresql_dump

| キー | 説明 | デフォルト |
| --- | --- | --- |
| host | 接続先ホスト | localhost |
| user | 接続ユーザー | postgres |
| password | パスワード | null |
| databases | 対象データベース名の配列 | [] |
| port | ポート番号 | 5432 |
| days | ダンプファイル保管日数 | 7 |
| dest.dir | 出力先ディレクトリ | /var/backups/db |

### postgresql_snapshot

| キー | 説明 | デフォルト |
| --- | --- | --- |
| target | 対象ZFSパーティション | zroot/postgres |
| days | スナップショット保管日数 | 3 |
| dsn | PostgreSQL接続文字列 | postgres://postgres@localhost/mastodon |

### mastodon（共通設定）

| キー | 説明 | デフォルト |
| --- | --- | --- |
| user | 実行ユーザー | mastodon |
| rails_env | RAILS_ENV環境変数 | production |
| dir | Mastodonインストールディレクトリ | /home/mastodon/repos/mastodon |

### service_restart

| キー | 説明 | デフォルト |
| --- | --- | --- |
| services | 再起動するサービス名の配列 | [] |

### mastodon_maintenance

| キー | 説明 | デフォルト |
| --- | --- | --- |
| commands | 実行するtootctlサブコマンドの配列 | [cache recount accounts, accounts cull] |

### mastodon_follow

| キー | 説明 | デフォルト |
| --- | --- | --- |
| account | 強制フォローするアカウント名 | info |

### mastodon_media_cleanup

| キー | 説明 | デフォルト |
| --- | --- | --- |
| commands | 実行するtootctlサブコマンドの配列 | [media remove-orphans, media remove --remote-headers, preview_cards remove -c 1] |

### rsync_backup

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dest | SSH転送先 (user@host:/path) | user@host:/path/to/backup |
| sources | バックアップ対象ディレクトリの配列 | [/etc, /usr/local/etc, ...] |
| excludes | 除外パターンの配列 | [.git, .zfs, .cache, node_modules, vendor/bundle, tmp, \*.bak, \*.log, \*.swp, \*.tmp] |

## ライセンス

MIT
