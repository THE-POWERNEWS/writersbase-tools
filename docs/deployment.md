# 配り方と運用

⚠ **このリポジトリは gem ではない。**利用側はサーバへ **git で checkout し、root で `bundle install` → `bundle exec rake install`** して cron / periodic にスクリプトを置く。**`bundle update` では届かない**ので、「main にマージした」は「動いている」を意味しない。

## 配布経路は 2 つある

| 経路 | 構成管理 | cookbook | 対象 |
| --- | --- | --- | --- |
| chubo2 → [pooza/chubo-core](https://github.com/pooza/chubo-core) | `bin/chubo --recipes=writersbase_tools` | `cookbooks/writersbase_tools` | Mastodon / Misskey フリート（本番 4・ステージング 4） |
| [THE-POWERNEWS/writersbase-env](https://github.com/THE-POWERNEWS/writersbase-env) | `bin/chubo --recipes=tools` | `app/cookbooks/tools` | `vpn` / `wiki` |

⚠⚠ **cookbook 名も node の設定キーも別物**（`writersbase_tools` と `tools`）。片方を直しても、もう片方は追随しない。

### 差分

- **チェックアウトの管理**
  - env 側は `RecipeGitRef.update_command`（`ff_only`、既定 `main`）で **clone / update までやる**
  - ⚠ **chubo-core 側はリポジトリの clone を管理していない**（`only_if "test -f #{path}/Gemfile"`）。**サーバ上で手で `git pull` する必要がある**
- **設定ファイル**
  - `Ginseng::Config` は `/usr/local/etc/writersbase-tools/`（FreeBSD）/ `/etc/writersbase-tools/`（Ubuntu）を直接読む
  - chubo-core はそこへ `local.yaml` を置き、**リポジトリ内へのシンボリックリンクは張らない方針**（古いリンクがあれば削除する）
  - env 側は `config/local.yaml` → `/etc/writersbase-tools/local.yaml` の**リンクを張る**（実体は 1 つなので shadow にはならない）
  - 🔴 **`local.yaml` は「先に見つけたディレクトリが勝つ」**（`next if @raw.key?(key)`）。⚠⚠ **chubo2 経路のノードでチェックアウトに `config/local.yaml` を作ると、`/usr/local/etc/.../local.yaml` が丸ごと無視される**（マージではない）。探索順は [README.md](../README.md) の「設定」
- **periodic の入れ替え**: env 側は `rake uninstall` → `rake install`、chubo-core 側は `rake install` のみ

### 共通の前提

- **root で bundler が使えること。**FreeBSD は `gem install bundler`（⚠ pkg の `rubygem-bundler` は使わない方針）、Ubuntu は `ruby-bundler` / `ruby-dev` / `build-essential` / `libpq-dev` / `default-libmysqlclient-dev` / `zstd`
- ⚠ **`rake install` は `bundle exec` を挟むこと。**素の `rake` だと default gem が先に activate され、`Gemfile.lock` の rake と衝突して `Gem::LoadError` で落ちる（chubo-core `257f3d0`）
- ⚠ **Gemfile が `mysql2` と `pg` を無条件に要求する。**MySQL を使わないノードでもクライアントライブラリが要る
- ⚠ **bash が要る。**ダンプは `bash -o pipefail -c` でパイプラインを実行する（#62）。FreeBSD では base に無く、フリートは `freebsd::deployer` の `package 'bash'` で入っている。**この recipe を当てていないノードへ配るときは bash を入れること**
- ログは rsyslog で `/var/log/writersbase-tools.log` に振り分け、newsyslog（FreeBSD）/ logrotate（Ubuntu）で回す

## ⚠ 罠

- ⚠⚠ **`rake install` は cron を書き換える。**長期間更新していないノードへ「ついでに流す」ができない。**そのノードのバックアップ系 cron を止めうる**（THE-POWERNEWS/writersbase-env#137）
- ⚠⚠ **配列の設定は「マージ」ではなく「置換」。**`Ginseng::Config` は `/google_drive_backup/excludes` のような平坦キーを後勝ちさせるので、node yaml に書くと **`config/application.yaml` の既定 10 件（`.git` / `node_modules` / `vendor/bundle` / `tmp` / `.cache` / `*.bak` …）が丸ごと消える**。書き足すつもりなら**既定を書き写した上に足す**
- ⚠⚠ **`google_drive_backup` は `rclone sync`＝宛先の余剰ファイルを削除する。**ステージングは `path: /backup/staging/devNN` で本番の `/backup/<host>` と分離すること。共有すると本番バックアップを消しうる
- ⚠⚠ **`postgresql_snapshot` の `dsn` は必須**（#87 で既定を外した）。書いていなければ `ConfigError` で落ちる ＝ **PostgreSQL へ繋ぐ前に止まる**。⚠ かつての既定は `postgres://postgres@localhost/mastodon` で **DB 名まで埋まっていた**ため、DB 名の違うノード（Misskey 等）へそのまま写すと**存在しない DB に繋いで毎時ジョブが黙って失敗し続けた**。⚠ `postgresql_dump` には **`dsn` というキーは無い**（`host` / `user` / `password` / `port` / `databases` を個別に書く）
- ⚠ **tootctl 系は `bash -lc` 経由で実行する**（#44 / `bdd5f3a`）。cron の非ログインシェルでは rbenv が初期化されず、OS の Ruby にフォールバックする
- ⚠ **FreeBSD の periodic daily は着火時刻が固定ではない。**先行タスク（rclone）の所要時間ぶん後ろへズレる。**「毎晩 N 時に走る」前提で手順を書かないこと**。⚠⚠ **2026-09-18 まで 1 日 2 回走っていた** — `/etc/crontab` の `periodic daily` に加え、anacron が「今日まだ走っていない daily」を拾っていた（daily だけでなく weekly / monthly も二重）。**pooza/chubo2#243 で FreeBSD 10 台から anacron ごと外して解消済み**。⚠ 実測は 2026-09-18 現在 `anacron=absent` / `crontab_daily=1`
- ⚠ **`service_restart` に `mastodon-web` を入れると外形監視がダウンとして拾う。**puma の復帰に 30〜45 秒かかる（pooza/chubo2#125 で `mastodon-sidekiq` だけへ縮小済み）
- ⚠ **rclone.conf は実行時の状態ファイル。**無条件に上書きすると更新済み access_token が巻き戻り、しかも itamae がテンプレートの差分を標準出力に出すので **refresh_token が平文でログと Slack に流れる**。chubo-core は `not_if 'test -f ...'` に是正済み

## ⚠⚠ 1.7.0 を配るときに知っておくこと

**periodic / cron のスクリプトが `bundle install` をやめた**（#68）。⚠ **スクリプトの中身が変わるので、`rake install` を流し直すまで古いスクリプトが残る**（＝ 古いノードでは従来どおり毎回 `bundle install` する）。

```sh
#!/bin/sh
set -e
cd '<チェックアウト>'
export BUNDLE_SILENCE_ROOT_WARNING=1
if ! bundle_check=$(bundle check 2>&1); then
  echo "$bundle_check" >&2
  echo 'writersbase-toolsのbundleが未充足です。構成管理を流して入れ直してください。' >&2
  exit 1
fi
bin/wb <ツール名>
```

- ⚠⚠ **依存を入れるのは構成管理の仕事になった。**`git pull` しただけで `Gemfile` が動いたノードは、**次の cron で「未充足です」と言って exit 1** する。⚠ **`bundle install` を流すこと**（chubo-core / env の cookbook はどちらも流す）
- ⚠ **`bundle check` は原則ネットワークに出ない**（`Gemfile.lock` が解決済みのとき）。⚠⚠ **未充足のときだけ** rubygems.org へ問い合わせに行くことがある
- ⚠ **`set -e` が付いた。**`cd` に失敗したら `bin/wb` を叩かずに落ちる（従来は**別のディレクトリの `bin/wb` を叩きうる**状態だった）
- ⚠ `bundle config silence_root_warning true` をやめ、環境変数 `BUNDLE_SILENCE_ROOT_WARNING=1` にした。**チェックアウトへ `.bundle/config` を書きに行かない**ため

**もう 1 つ、実行のハートビートが増えた**（#91）。⚠ **`heartbeat.tokens` を書いたノード・ツールだけ**送るので、**書かなければ挙動は変わらない**。

- 🔴 **成功時も送る。**push モニタは「途切れたら DOWN」という向きなので、**そもそも走らなかった**（宣言漏れ・ノード停止）も拾える。⚠ pooza/chubo2#244（monit → Kuma）と同じ経路・同じ宛先
- ⚠⚠ **Kuma 側にモニタを登録しないと、送っても誰も見ない。**interval は**そのツールの実行間隔**に合わせること（daily の道具に 300s を設定すると即 DOWN になる）
- ⚠⚠ **push URL はそれ自体が資格情報。**node yaml ではなく暗号化された経路／`local.yaml`（0600）へ。⚠ ログでは `[FILTERED]` になる（`CommandLine#secrets`）
- ⚠ `curl` が要る（chubo-core の monit → Kuma と同じ）。無いノードでは警告が出るだけで、**本業は落ちない**

## ⚠⚠ 1.6.0 を配るときに知っておくこと

**1.6.0 は「失敗が見えるようになる」リリース。**これまで黙って成功に見えていたものが、periodic のメールと Sentry に出始める。⚠ **反映直後に「新しい失敗が増えた」ように見えるが、実際にはこれまで見えていなかったもの。**

- ⚠ **ツールが失敗すると非ゼロで終わる**（#64）。periodic は非ゼロ終了と出力でメールを出す
- ⚠ **`rake install` も失敗すると非ゼロ**（#72）。**itamae が赤くなるノードは、実際に periodic が置けていない**
- ⚠⚠ **`target`（ZFS データセット）と `rsync_backup` の `dest` は必須になった**（#67）。node yaml に書いていなければ、そのツールは落ちる。⚠ 確認した範囲（chubo2 の 4 ノード・writersbase-env）ではすべて明示済み
- ⚠ **ダンプは `bash -o pipefail -c` で走る**（#62）。bash の無いノードへ配らないこと
- ⚠⚠ **モロヘイヤの webhook URL を再発行すること**（#65）。これまでのログに平文で残っている
- ⚠ ログのマスクが `Ginseng::Masking` へ寄った（#66）。伏せられた値は `***` ではなく**キーごと消える**か `[FILTERED]` になる

## 本ツール側に残っている課題

- ⚠ **`zfs destroy` の非ゼロ終了を拾っていない件（#63）は 1.6.0 で修正済み。⚠⚠ ただしリリース前**なので、稼働中のノードでは**まだログの `delete` は削除の証拠にならない**（生死は `zfs list -t snapshot` で見る）。`zfs hold` で守られたスナップショットは `failure` へ落ちるようになる
- ⚠ **Redis の口が無い。**旧世代 periodic の `backup-redis` に相当するツールが無く、Misskey 側の移行時に落ちた
- ⚠ **設定ドキュメントが手書き。**ツールを足すたびに README の表を更新する運用（#15 が自動生成を提案している）

利用側の設定・レート制限・バックアップ対象の絞り込みといった課題は**利用側の Issue**（pooza/chubo2#193 / pooza/chubo2#194 等）に立っている。境界は [CLAUDE.md](CLAUDE.md) の「情報の記載先ルール」。
