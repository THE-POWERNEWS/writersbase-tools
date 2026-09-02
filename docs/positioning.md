# 位置づけと背景

## 何であるか

サーバ上で定期実行する保守処理（バックアップ・スナップショット・ログ圧縮・SNS の保守コマンド）の**受け皿**。Ruby + [ginseng-core](https://github.com/pooza/ginseng-core) で書き、`bin/wb <ツール名>` で単発実行し、`rake install` で cron / periodic に配る。

- 各ツールは `WritersBase::Tool` を継承し、`exec` と `description` だけを実装する
- 設定は `config/application.yaml` を既定、サーバ側の `config/local.yaml` で上書きする
- 前身は各サーバに手書きで置かれていた `ginseng-*` の periodic スクリプト群（`compress-access-log` / `backup-postgres` / `sidekiq-restart` 等）。それを 1 リポジトリに寄せたもの

## ⚠⚠ 名前に反して writersBASE 向けではない

**これは構成の問題であって、ツールの品揃えの問題ではない**（2026-09-01・writersbase-env の [progress-2026-09.md](https://github.com/THE-POWERNEWS/writersbase-env/blob/main/docs/history/progress-2026-09.md)）。

- writersBASE のドメインは **Prisma（TypeScript）と WordPress（PHP）**にある。ドメインを触る道具を Ruby で書くと**スキーマを二重に持って Prisma を迂回する**ことになる
- そのため writersBASE 固有の道具は、それぞれ自然な場所に落ちた — `writersbase-backend/bin/encrypt-token.js`、`writersbase-backend/src/scripts/backfill_article_plaintext.ts`、`writersbase-env/tools/demo-data/`
- ⚠ **writersBASE 側で品揃えが空に見えるのは、DB をマネージド（Linode Managed Database）に預けていてサーバ上に状態が無いから。** 自前ホスト＋ZFS に移す前提では `mysql_snapshot` / `mysql_dump` / `rsync_backup` / `google_drive_backup` / `service_restart` / `access_log_compress` / `reboot_required` と、**13 のうち 6〜7 が現役になる**（ユーザーの見立て・2026-09-01）

⚠ **「いま使われていない」を「要らない」と読み替えないこと。** 上記の前提を踏まえずに撤去や縮小を提案しない。

## 実際の利用者は chubo2 のフリート

| 利用側 | 何に使っているか | 状態 |
| --- | --- | --- |
| [pooza/chubo2](https://github.com/pooza/chubo2)（Mastodon / Misskey フリート） | 日次・毎時のバックアップ、ZFS スナップショット、ログ圧縮、`service_restart`、tootctl 系保守 | **主たる利用者。**本番 4 台（FreeBSD 3 + Ubuntu 1）＋ステージング 4 台で稼働中 |
| [THE-POWERNEWS/writersbase-env](https://github.com/THE-POWERNEWS/writersbase-env) | ⚠ `tools.enable` が真なのは **`vpn` と `wiki` の 2 ノードだけ**（アプリのノードはすべて false） | 🔴 **どこでも最新版が動いていない**（下記） |

雑多なバッチの受け皿という性質から、**要求の出どころは chubo2 のほうが多い**。⚠ **名前から利用側を推測しないこと。**

### 🔴 writersBASE 側は最新版が動いていない（2026-09-01 実測）

- `vpn.writersbase.net` … ⚠ **名前が解決しない。**ノードファイルも雛形だけ
- `wiki.writersbase.net` … 稼働中だが **2025-05-21 の版（`a6aaf78`）で止まっている**（`main` まで 93 コミット）
- ⚠ **「ついでに流す」ができない。**`--recipes=tools` は 15 か月分の更新になり、`bundle install` が Ruby 3.2.3 で走り、`rake uninstall` / `rake install` が **cron を書き換える**。そのノードのバックアップ系 cron を止めうる
- → **THE-POWERNEWS/writersbase-env#137** として切り出し済み。#37（Sentry）のクローズはそこまで待つ

⚠ **「失敗しても誰も気づかない」を直すための #37 が、まさに誰も気づかないまま放置されていたノードで止まっていた**という形になっている。

## 独立プロジェクトとしての扱い（2026-09-02〜）

- リポジトリ名・パス・cookbook 名は `writersbase-` のまま変えない（サーバ上のパス・ログのタグ・rsyslog の設定に埋まっており、改名の手間が利得を上回る）
- **規約類は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) に準じる**（writersBASE 側の `docs/policy/` ではない）
- **運用（進捗の同期・リリース手順）は [pooza/mulukhiya-toot-proxy](https://github.com/pooza/mulukhiya-toot-proxy) の形を踏襲する** — 詳細は [CLAUDE.md](CLAUDE.md)
- 課題の起票先は本リポジトリ。**利用側の設定・配備の課題は利用側**（chubo2 / writersbase-env）へ。境界は [CLAUDE.md](CLAUDE.md) の「情報の記載先ルール」
