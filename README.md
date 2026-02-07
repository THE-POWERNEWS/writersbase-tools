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

`config/application.yaml`の`hourly`、`daily`、`weekly`、`monthly`にツール名を設定し、
rakeタスクでcronスクリプトとしてインストールできます。

```sh
rake install    # cronスクリプトをインストール
rake uninstall  # cronスクリプトをアンインストール
```

## ツール

| ツール名 | 説明 |
| --- | --- |
| access_log_compress | 指定日数が経過したログファイルをgzip圧縮します。 |
| help | ツール一覧を表示します。 |
| mysql_dump | MySQLのダンプファイルを作成します。 |
| postgresql_dump | PostgreSQLのダンプファイルを作成します。 |
| postgresql_snapshot | PostgreSQLのZFSスナップショットを作成・管理します。 |
| reboot_required | システムに再起動が必要かを判定します。 |

## 設定

`config/application.yaml`で各ツールの動作を設定します。

### access_log_compress

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dir | 対象ディレクトリ | /var/log/nginx |
| days | 経過日数 | 1 |

### mysql_dump

| キー | 説明 | デフォルト |
| --- | --- | --- |
| host | 接続先ホスト | localhost |
| user | 接続ユーザー | root |
| password | パスワード | null |
| databases | 対象データベース名の配列 | [] |
| port | ポート番号 | 3306 |
| days | ダンプファイル保管日数 | 7 |
| dest.dir | 出力先ディレクトリ | /var/backups/db |

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

## ライセンス

MIT
