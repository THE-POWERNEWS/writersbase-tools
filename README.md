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

設定（下記「[設定](#設定)」の探索先のいずれか）の`hourly`、`daily`、`weekly`、`monthly`に
ツール名を設定し、rakeタスクでcronスクリプトとしてインストールできます。

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

`config/application.yaml`にデフォルト値が定義されています。環境固有の設定は
`local.yaml`を作成して、必要な項目のみ上書きしてください（`application.yaml`を直接
編集する必要はありません）。`local.yaml`はGit管理対象外です。

### ⚠ 未定義のキーは例外になります

`Ginseng::Config`は**未定義のキーで`ConfigError`を投げます**（`nil`は返しません）。
⚠⚠ **`dsn: null`のように`null`を書くと、キーごと落ちます**（＝未定義と同じ扱い）。

- **無ければ既定へ倒したい設定**は`Config#lookup(キー, 既定)`を通します（#104）。
  ⚠ `config[...] || 既定`や`config[...] != false`は「キーが無くても動く」ように読めますが、
  **`||`に到達する前に例外になります**
- **無ければ落ちてほしい設定**（`postgresql_snapshot`の`target` / `dsn`など）は素のまま読みます。
  ⚠⚠ **それらしい既定を持たせると、別のノードへ写したときに黙って空振りします**（#67 / #87）

### 探索先と優先順

`Ginseng::Config`は**3つのディレクトリ**を、この順に探します。

| # | ディレクトリ | 実際に使っているノード |
| --- | --- | --- |
| 1 | `<チェックアウト>/config` | 手元の開発環境 |
| 2 | `/usr/local/etc/writersbase-tools` | FreeBSD（shallu / zugoga / gomander） |
| 3 | `/etc/writersbase-tools` | Ubuntu（vulcan / wiki / vpn） |

各ディレクトリの中では、ファイル名が**`<ホスト名>.yaml` → `local.yaml` →
`application.yaml` → `lib.yaml`** の順に優先されます（先にあるものが勝ち）。

- ⚠ **`<ホスト名>`は`Socket.gethostname`の値**です。フリートの各機はFQDNを返すので、
  ファイル名も`shallu.b-shock.co.jp.yaml`のようになります（`shallu.yaml`では効きません）。
  **いまどのノードも使っていませんが、仕様としてあります**
- ⚠ **チェックアウトの`config/`に`local.yaml`は置かれていません。**配備済みノードの実効設定は
  上の表の2・3にあります（2026-09-18に本番4台で実測）。README を読んで
  `config/local.yaml`を探しても見つからないのは、そのためです

🔴 **`local.yaml`は「先に見つけたディレクトリが勝つ」。マージではありません。**

```ruby
key = File.basename(f, suffix)  # Ginseng::Config#load
next if @raw.key?(key)
```

⚠⚠ **ここでの`key`は設定キーではなく、拡張子を除いたファイル名**（`local` / `application`）です。
だから**キー単位のマージではなく、ファイル単位で丸ごと捨てられます**。
2つのディレクトリに別々のキーを書いた`local.yaml`を置いて実測すると、
後ろのディレクトリのキーは`ConfigError`（未定義）になります。

⚠⚠ **手元で試すつもりでチェックアウトに`config/local.yaml`を置くと、
`/usr/local/etc/writersbase-tools/local.yaml`（＝配備済みの実効設定）は
丸ごと無視されます。**サーバ上のチェックアウトで一時的にキーを足したいときも、
ファイルごと上書きしてしまうので、⚠ **配備済みノードでは`config/`に`local.yaml`を作らないこと。**

⚠ 配布経路によって置き場が違い、**writersbase-env側だけは
`config/local.yaml` → `/etc/writersbase-tools/local.yaml`のシンボリックリンクを張ります**
（この場合は実体が1つなのでshadowになりません）。経路ごとの差は
[docs/deployment.md](docs/deployment.md)を参照してください。

### heartbeat（実行の監視）

実行のたびに **Uptime Kuma の push モニタ**へハートビートを送ります（#91）。

| キー | 説明 | デフォルト |
| --- | --- | --- |
| base | push エンドポイントの URL | `https://uptime.b-shock.org/api/push` |
| timeout | 送信のタイムアウト秒数 | 20 |
| tokens | **ツール名 → push トークン**。書いたツールだけ送る | `{}` |

```yaml
heartbeat:
  tokens:
    postgresql_dump: xxxxxxxxxxxx
    google_drive_backup: yyyyyyyyyyyy
```

🔴 **成功時も送ります。**push モニタは「ハートビートが途切れたら DOWN」という向きなので、
成功を送らないと「走った」ことが伝わりません。⚠ **これは欠点ではなく利点で、
「そもそも走らなかった」（宣言漏れ・ノード停止・cron の設置漏れ）も DOWN になります** ——
Sentry には無い利点です。

- 成功 … `status=up` / `msg=OK`
- 失敗 … `status=down` / `msg=<失敗の要約>`（⚠ 200 文字で切り、Sentry と同じ網で伏せてから送ります）

⚠⚠ **push URL（トークン）はそれ自体が資格情報です。**`local.yaml` に置いてください。
⚠ トークンは**パスに入る**ため `Ginseng::HTTP` のログでは伏せられません。そのため送信は
`CommandLine#secrets` に載せた `curl` で行い、ログでは `[FILTERED]` になります。

⚠ **Kuma 側にモニタが無ければ、送っても誰も見ません。**モニタの登録と interval
（**ツールの実行間隔に合わせる**）は利用側の仕事です。

⚠ **監視の都合で本業は落としません。**送信に失敗しても警告を出すだけで、ツールの
終了コードは変わりません。

### sentry（エラー監視）

ツールの失敗を Sentry へ能動的に通知します（#37）。

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dsn | Sentry の DSN。**空なら Sentry は起動せず、何も送らない** | null |
| environment | Sentry 側の環境名。省略時は `/environment` の値 | null |
| traces_sample_rate | 性能計測の採取率。`0` なら計測しない | 0 |
| scrub_patterns | 送信前に伏せる正規表現。`\K` で値だけを伏せる | 下記 |

⚠ **DSN は秘密ではありません**（送信専用・公開情報）ので、`local.yaml` に
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
| single_transaction | `--single-transaction`を渡す | true |

⚠⚠ **`single_transaction`は、MyISAMのテーブルを含むデータベースでは`false`にしてください。**

`mysqldump`の既定は`--opt`で、**`--lock-tables`と`--quick`は既に有効**です（実測: `lock-tables TRUE` / `quick TRUE` / `single-transaction FALSE`）。つまり既定でも1つのデータベースの中では一貫していますが、⚠ **ダンプのあいだ書き込みが止まります**。

`--single-transaction`は`--lock-tables`を**自動的に無効化**し、InnoDBのMVCCで一貫性を取ります。書き込みを止めずに済む代わりに、🔴 **MyISAMのテーブルには何の保護も無くなります**（#79）。⚠ ダンプ中のDDLでも壊れます。

### mysql_snapshot

| キー | 説明 | デフォルト |
| --- | --- | --- |
| target | 対象ZFSパーティション | ⚠ **null（必須）** |
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
| target | 対象ZFSパーティション | ⚠ **null（必須）** |
| days | スナップショット保管日数 | 3 |
| dsn | PostgreSQL接続文字列 | ⚠ **null（必須）**<br>⚠⚠ 未設定なら`ConfigError`で落ちます（#87） |

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

⚠ **Webhook URLはそれ自体が資格情報**なので、`local.yaml`側に置いてください。🔴 **ログと例外では伏せていますが、実行中は`ps`から読めます**（`--webhook <url>`としてtootctlの引数に載るため・#127）。`origin`が未設定のときは「毎日静かに何もしない」状態を避けるため実行時にエラーにします。

### google_drive_backup

⚠⚠ **`rclone sync` を使います。**宛先を間違えると、宛先側の余剰ファイルが消えます。

| キー | 説明 | デフォルト |
| --- | --- | --- |
| remote | rcloneリモート名 | gdrive |
| path | Google Drive上のバックアップ先パス（⚠ **ホスト名を含めること**） | ⚠ **null（必須）** |
| sources | バックアップ対象ディレクトリの配列 | [/etc, /usr/local/etc] |
| excludes | 除外パターンの配列 | [.git, .zfs, .cache, node_modules, vendor/bundle, tmp, \*.bak, \*.log, \*.swp, \*.tmp] |
| links | シンボリックリンクを`.rclonelink`として保存する（`--links`） | true |

事前に`rclone config`でGoogle Driveリモートを設定しておく必要があります。

⚠⚠ **`path`には必ずホスト名を含めてください**（`/backup/shallu.b-shock.co.jp`）。宛先は`<remote>:<path>/<source>`で組み立てられ、**ホスト名はどこにも自動で入りません**。🔴 以前の既定`/backup`のまま2台目を走らせると、宛先が1台目と同じ`gdrive:/backup/etc`になり、**先に置かれていたぶんを`rclone sync`が削除します**（#120）。未設定・空文字のときは実行時にエラーにします。

⚠⚠ **`links`を`false`にするとシンボリックリンクがバックアップから落ちます。**🔴 **しかも`rclone`は`exit 0`で終わります**（`NOTICE`を出すだけ）。ツール側は成功として扱うので、**落ちたことに誰も気づけません**（#97）。⚠ rclone 1.60.1 / 1.75.1 とも同じ挙動であることを実測済みです。⚠ `true`にすると宛先に`.rclonelink`というテキストファイルが生えます。後から`false`へ戻すと、`rclone sync`が宛先のそれらを削除します。

### rsync_backup

⚠⚠ **`rsync --delete` を使います。**宛先を間違えると、宛先側の余剰ファイルが消えます。

| キー | 説明 | デフォルト |
| --- | --- | --- |
| dest | SSH転送先 (user@host:/path) | ⚠ **null（必須）** |
| sources | バックアップ対象ディレクトリの配列 | [/etc, /usr/local/etc, ...] |
| excludes | 除外パターンの配列 | [.git, .zfs, .cache, node_modules, vendor/bundle, tmp, \*.bak, \*.log, \*.swp, \*.tmp] |

## ドキュメント

開発の進め方・配り方・位置づけは [docs/](docs/README.md) にあります。

- [docs/CLAUDE.md](docs/CLAUDE.md) — 規約の正本・ブランチ・リリース運用・進捗の同期手順
- [docs/positioning.md](docs/positioning.md) — 位置づけと背景
- [docs/deployment.md](docs/deployment.md) — 配り方と運用の罠

## ライセンス

MIT
