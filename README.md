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
| misskey_emoji_sync | 姉妹Misskeyサーバーからカスタム絵文字を取り込み、増えたぶんを告知します。 |
| mysql_dump | MySQLのダンプファイルを作成します。 |
| mysql_snapshot | MySQLのZFSスナップショットを作成・管理します。 |
| postgresql_dump | PostgreSQLのダンプファイルを作成します。 |
| postgresql_snapshot | PostgreSQLのZFSスナップショットを作成・管理します。 |
| reboot_required | システムに再起動が必要かを判定します。 |
| google_drive_backup | rcloneでファイルをGoogle Driveにバックアップします。 |
| rsync_backup | rsyncでファイルを外部サーバーにバックアップします。 |
| service_restart | 設定されたサービスを再起動します。 |

## 設定

`config/application.yaml`にデフォルト値が定義されています。
環境固有の設定は`config/local.yaml`を作成し、必要な項目のみ上書きしてください（`application.yaml`を直接編集する必要はありません）。
`config/local.yaml`はGit管理対象外です。

### sentry（エラー監視）

ツールの失敗を Sentry へ能動的に通知します（#37）。

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dsn | Sentry の DSN。**空なら Sentry は起動せず、何も送らない** | null |
| environment | Sentry 側の環境名。省略時は `/environment` の値 | null |
| traces_sample_rate | 性能計測の採取率。`0` なら計測しない | 0 |
| scrub_patterns | 送信前に伏せる正規表現。`\K` で値だけを伏せる | 下記 |

⚠ **DSN は秘密ではありません**（送信専用・公開情報）ので、`config/local.yaml` に
平文で構いません。

#### 送るもの

`bin/wb` の最終 `rescue` で拾った例外だけを送ります。ツールの例外はすべてここへ
来るので、集約点はここ 1 か所です。fingerprint にツール名を混ぜているため、
別のツールの失敗が同じ issue にまとめられることはありません。

⚠ **bundle 未充足の早期失敗は対象外です。** SDK 自体がまだ読めていないためです。

⚠ **送信後に必ず flush します。** cron から呼ばれる道具は送信直後に終了するので、
既定の非同期送信のままではプロセスが先に消えてイベントが届きません。

#### 送らないもの

- URL の userinfo（`postgres://user:pass@host`）
- コマンドラインの環境変数（`MYSQL_PWD=` / `PGPASSWORD=`）
- `token` / `access_token` / `password` / `secret` などの `key=value`

⚠ **例外メッセージだけでなく、スタックトレースに載るソースの行**
（`context_line` / `pre_context` / `post_context`）にも同じ網を掛けています。
Sentry は例外が起きた行の前後を丸ごと送るため、メッセージだけ伏せても足りません。

⚠ マスクの正本は `Ginseng::Masking` です。**ログ側もそちらへ寄せてあり**（#66）、
`--webhook` のような `scrub_patterns` は取りこぼしに対する保険として残しています。

#### ログのマスク

ログのマスクも `Ginseng::Masking` が行います。対象は `config/application.yaml` の
`/logger/*` で**足します**。⚠ **既定と合成されるので、減らす方向へは効きません。**

| キー | 説明 |
| --- | --- |
| mask_fields | 伏せる Hash のキー名。⚠ 伏せた値は**キーごと落ちます**（`***` への置換ではありません） |
| mask_url_paths | URL の**パス**に現れたら次の 1 セグメントを伏せる接頭辞。モロヘイヤの webhook URL はクエリではなくパスにダイジェストが載ります |

⚠⚠ **独自のマスクを書き足さないこと。**以前ここに置いていた `deep_mask_keys` は
`Ginseng::Logger#mask` と名前が衝突しており、ginseng-core を上げた瞬間に
**全ログが `_mask_error` になる**形でした（#66 で撤去）。

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

### misskey_emoji_sync

| キー | 説明 | デフォルト |
| --- | --- | --- |
| origin | 取り込み元のMisskeyサーバーのURL | null（未設定なら実行時にエラー） |
| webhook | 告知先のWebhook URL | null（未設定なら告知しない） |

`bin/tootctl emoji sync <origin> --no-dry-run` を実行します。`webhook`を設定すると、増えた絵文字の告知をそのURLへSlack互換のペイロードで投稿します（モロヘイヤのアカウント別Webhookを想定）。

⚠ **Webhook URLはそれ自体が資格情報**なので、`config/local.yaml`側に置いてください。`origin`が未設定のときは「毎日静かに何もしない」状態を避けるため実行時にエラーにします。

### google_drive_backup

| キー | 説明 | デフォルト |
| --- | --- | --- |
| remote | rcloneリモート名 | gdrive |
| path | Google Drive上のバックアップ先パス | /backup |
| sources | バックアップ対象ディレクトリの配列 | [/etc, /usr/local/etc] |
| excludes | 除外パターンの配列 | [.git, .zfs, .cache, node_modules, vendor/bundle, tmp, \*.bak, \*.log, \*.swp, \*.tmp] |

事前に`rclone config`でGoogle Driveリモートを設定しておく必要があります。

### rsync_backup

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dest | SSH転送先 (user@host:/path) | user@host:/path/to/backup |
| sources | バックアップ対象ディレクトリの配列 | [/etc, /usr/local/etc, ...] |
| excludes | 除外パターンの配列 | [.git, .zfs, .cache, node_modules, vendor/bundle, tmp, \*.bak, \*.log, \*.swp, \*.tmp] |

## ドキュメント

開発の進め方・配り方・位置づけは [docs/](docs/README.md) にあります。

- [docs/CLAUDE.md](docs/CLAUDE.md) — 規約の正本・ブランチ・リリース運用・進捗の同期手順
- [docs/positioning.md](docs/positioning.md) — 位置づけと背景
- [docs/deployment.md](docs/deployment.md) — 配り方と運用の罠

## ライセンス

MIT
