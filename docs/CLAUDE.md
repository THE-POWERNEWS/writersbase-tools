# writersbase-tools 開発ガイド

VPS 上で定期実行する保守バッチの受け皿。**2026-09-02 に独立したプロジェクトとして扱うことにした。**

- 何であるか・誰が使っているか → [positioning.md](positioning.md)。⚠ **名前に反して writersBASE 向けではない**
- どう配られるか・運用の罠 → [deployment.md](deployment.md)
- ツール一覧・設定キー → [README.md](../README.md)

## 規約の正本

⚠⚠ **Ruby の書き方・進め方・表記の正本は [pooza/ginseng-style](https://github.com/pooza/ginseng-style) の `docs/`。** 以下には writersbase-tools 固有の差分だけを置く。

| ドキュメント | 内容 |
| --- | --- |
| [docs/ruby.md](https://github.com/pooza/ginseng-style/blob/main/docs/ruby.md) | 暗黙の return を使わない／論理的 2 スペース／`disable?` パターン／文字列のエンコーディング |
| [docs/workflow.md](https://github.com/pooza/ginseng-style/blob/main/docs/workflow.md) | Issue 駆動・ブランチ・マイルストーンとサイズラベル・リリース前レビュー・依存の制約 |
| [docs/writing.md](https://github.com/pooza/ginseng-style/blob/main/docs/writing.md) | 用語・パスとキーの書き方・⚠ マーカーの使い方・クロスリポジトリの Issue 参照 |

⚠ **共通に見える緩和を `.rubocop.yml` に足さないこと。** 共通化したい場合は pooza/ginseng-style に Issue を立てる。

### 固有の差分

- `.rubocop.yml` は `inherit_gem` の上に **`TargetRubyVersion: 3.3`** だけを置く。⚠ **CI が ruby 3.3.10 で回る**ため（配る既定は 3.4）。CI の版を上げたらここも上げる
- `Gemfile` の `ginseng-style` は **SHA 固定**（`ed862dcf…` ＝ v1.1.12）。⚠ **タグは付け替えられるので `tag:` へ戻さない**（pooza/ginseng-style#75・#70）
- CI は ginseng-style の composite action（`ruby-check`）を使う（#69）。⚠⚠ **参照の SHA は `Gemfile` の ginseng-style と同じものに揃える。**版を上げるときは 2 か所を同時に書き換える
- ⚠ `ginseng-core` は `Gemfile` で **タグ固定**（`tag: 'v1.23.7'`・#94 ＝ pooza/ginseng-style#103 のロールアウト）。⚠ **移行で revision は 1 ビットも動いていない**（`b6e736d` は v1.23.7 のタグそのもので、`Gemfile.lock` の差分は `tag:` の 1 行だけ）。狙いは**破綻の受け皿を、無関係な `bundle update` から版を上げる PR の CI へ移すこと**
- ⚠⚠ **同じ「固定」でも ginseng-style は SHA、ginseng-core は tag。矛盾ではない。**ginseng-style は **CI で実行されるコード**（composite action。`release-tag` は呼び出し側の `contents: write` を受け取る）なので、**付け替え可能なタグ自体が脅威**になる（pooza/ginseng-style#75）。ginseng-core は**実行時の依存**で、要件は「いつ版が動くかを人が決めること」だけなので tag で足りる（#103 も「`tag:`（または SHA）」と書いている）。⚠ **どちらかに揃えようとして倒さないこと**

### 保留中の依存の更新

- ⏳ **`sentry-ruby` 7.0.0（PR #93）は意図的に保留**。tools が触る API（`Sentry.init` / `capture_exception` / `before_send` / `close`）は無傷だが、7.0.0 で **logs / metrics が既定で有効**になり（`enable_logs` / `enable_metrics` は撤去）、`send_default_pii` が deprecated（`data_collection` へ）。⚠⚠ **1.6.0 は「失敗が Sentry に出るようになる」リリースなので、送信経路の挙動が黙って変わるのは最も避けたい**。dev1 で例外を 1 件飛ばし `env` 付きで着弾するのを確認してからマージする。**閉じないこと**

## ブランチ

⚠ **`main` だけを使う。**feature ブランチを切って `main` へ直接 PR を出す。

- 命名は `fix/<issue>-<slug>` / `feat/<issue>-<slug>` / `chore/<issue>-<slug>`（実績は `feature/<issue>-<slug>` も混在）
- ✅ **`origin/develop` は 2026-09-19 に削除した。**⚠ **2025-04-13 〜 2026-02-23 は主力として使っていた**（PR #6〜#29 の **20 本**が `develop` → `main`。最後は #29 ＝ `fc6ace6`）が、⚠ **この規模の道具には合わない運用**だと判断して feature ブランチ直 PR へ移り、以後 7 か月使われないまま `main` に対し **behind 112 / ahead 0** になっていた（固有コミット 0 件・tip の `8591f92` は `main` の祖先だったので、失われたものは無い）。⚠⚠ **復活させないこと。**
- ⚠ **リモートに残っているブランチは `main` と作業中のものだけ**にする。マージ済みのブランチは PR のマージ時に消す（⚠ squash マージだと tip が `main` の祖先にならないので、`--merged` ではなく **PR の状態**で判断する）
- ⚠ `gh pr create` は `--base main` を明示する
- コミットメッセージには対応する Issue 番号を含める（`#37 Sentry を導入して…`）

## Issue とマイルストーン

- 課題・タスクは GitHub Issue で管理する。⚠ **docs に書いただけでは管理されていない扱い**
- サイズラベル（`size:S` = 1 / `size:M` = 3 / `size:L` = 8）と重み予算（1 マイルストーン 20〜25）は ginseng-style の `docs/workflow.md` が正本
- ⚠ **新しいマイルストーンに着手したら、まずバージョンをバンプする**（開発中の版を常に識別できる状態に保つ）。⚠⚠ **バンプは出荷の合図ではない。**出荷を確定させるのはタグ
- ⚠ **元の要件を先送りするときは、受け皿の後続 Issue を起票するまでクローズしない**

## リリース運用

**バージョンの正本は `config/application.yaml` の `/package/version`。**

1. マイルストーンの Issue をすべて消化する
2. **リリース前レビュー**（下記）。赤のみ本リリースで対応し、黄・緑は Issue 起票して次リリースへ送る
3. セキュリティ確認（Dependabot アラート・`bundle update`）
4. **実機での確認**（下記「リリース前の実機確認」）
5. `/package/version` をバンプ（着手時に済んでいれば不要）
6. `main` の CI が緑であることを確認する
7. `gh release create vX.Y.Z --target main --title "X.Y.Z"` でタグとリリースノートを作る
8. **リリース後**: 利用側へ反映する。⚠ **タグを打っただけでは 1 台にも届かない** — [deployment.md](deployment.md) の 2 経路を回し、pooza/chubo2 の `docs/infra-history.md` に反映を記録する

### v1.7.0 は出荷済み（2026-09-20 タグ）—— ⚠⚠ **まだ 1 台にも配っていない**

**最新タグは v1.7.0**（`cba2604`／公開 2026-09-20）。マイルストーン `1.7.0` の 7 件。
⚠⚠ **タグを打っただけで、本番 4 台に居るのは依然 v1.6.1**（vulcan は v1.6.0）。
**反映は [deployment.md](deployment.md) の 2 経路**を回すまで終わらない。

⚠ **ステージング（dev27）だけ先に `cba2604` へ上げてある**（実機確認のため・`bundle install` と
`rake install` まで通した）。⚠⚠ **`bin/chubo` を通していないので宣言と実機はずれたまま。**

🔴 **1.7.0 は「配布物と設定が変わる」リリース。**配るときは下の 3 つを外さないこと。

1. ⚠⚠ **`rake install` を流し直す**（#68 で periodic スクリプトの中身が変わる）。
   流し直すまで**古いスクリプトが残り、従来どおり `bundle install` し続ける**
2. ⚠ **先に `bundle install` を済ませる。**新しいスクリプトは `bundle check` で落ちる
   （⭕ **設計どおりの挙動**。dev27 で実際に踏んで確認した）
3. ⚠⚠ **`google_drive_backup` の `path` が必須になった**（#120・破壊的変更）。
   ✅ 配る前に 8 台すべてに `path` があることを実測済みなので、**1 台も落ちない**

| Issue | 内容 | 状態 |
| --- | --- | --- |
| #105 | 設定の置き場が実態とずれている | ✅ #110 |
| #68 | periodic が毎回 root で `bundle install` | ✅ #111 |
| #104 | 「無ければ既定」風の書き方が機能していない | ✅ #112（`Config#lookup`） |
| #91 | 失敗に気づける通知経路が無い | ✅ #113（⚠ **受け皿は pooza/chubo2#248**） |
| #101 | `mysql_dump` が MyISAM の混在を検出しない | ✅ **道具は直さない**（THE-POWERNEWS/writersbase-env#171 へ依頼） |
| #82 | `CommandLine#log_exec` の上書きを本体へ寄せる | ➡️ **1.7.1 へ送った**（⏳ 上流 pooza/ginseng-core#645 が open） |
| #120 | `google_drive_backup` の `path` 既定が共有の宛先を指す | ✅ #126（⚠ **破壊的変更**） |
| #121 | 資格情報がコマンドラインに載る | ✅ #128（⚠ `--webhook` は **#127** へ送り） |

#### リリース前レビュー: 2026-09-20（1.7.0）

⚠ **`main`（`a0ae750`）の `app/lib` 配下を単一セッションで全部読んだ。**v1.6.1（`8737a1c`）から **21 コミット**（`git rev-list --count --no-merges 8737a1c..a0ae750`。⚠ マージを含めると 35・first-parent なら 13）。赤 2・黄 3・緑 2。
⚠⚠ **赤 2 件はどちらも「1 行書き忘れたら壊れる」型**で、#67 / #87 で潰したはずの
**「それらしい既定」と「秘密の置き場」**が別の場所に残っていた。

| | Issue | 観点 |
| --- | --- | --- |
| 🔴 赤 | [#120](https://github.com/THE-POWERNEWS/writersbase-tools/issues/120) `google_drive_backup` の `path` 既定が共有の宛先を指す | 破壊的操作・設定の既定値 |
| 🔴 赤 | [#121](https://github.com/THE-POWERNEWS/writersbase-tools/issues/121) 資格情報がコマンドラインに載り、非 root から読める | セキュリティ |
| 🟡 黄 | [#122](https://github.com/THE-POWERNEWS/writersbase-tools/issues/122) 未対応プラットフォームで黙って倒れる 2 か所 | エラー処理 |
| 🟡 黄 | [#123](https://github.com/THE-POWERNEWS/writersbase-tools/issues/123) `access_log_compress` の既定が生ログに当たりうる | 破壊的操作・観測性 |
| 🟡 黄 | [#124](https://github.com/THE-POWERNEWS/writersbase-tools/issues/124) 同じ処理が 2 か所に写経されている | 規約整合性 |

- **#120** … `path: /backup` にホスト名が入らないので、**既定のまま 2 台目を走らせると 1 台目の `/backup/etc` を `rclone sync` が消す。**⚠ 4 台とも `local.yaml` で上書きしているので事故っていないだけ。⚠⚠ **`rsync_backup` の `dest`（#67）・`postgresql_snapshot` の `dsn`（#87）と同じ理由がここにだけ効いていない**
- **#121** … ⚠⚠ **`CommandLine#secrets`（#65）はログと例外を伏せるが、`ps` は伏せない。**実測で **vulcan は非 root（`misskey`）から root の `/proc/1/cmdline` が読め**、shallu は `security.bsd.see_other_uids: 1`。🔴 **`Heartbeat` の push URL は 1.7.0 で新しく入れた経路**。⚠ `misskey_emoji_sync` の `--webhook` は tootctl の仕様に縛られるので**道具側だけでは閉じない**
- ⚠ **#119（失敗時にログが残らない）も赤だが、1.7.1 へ送ると判断した。**道具の欠陥ではあるが、**出荷を止めるより先に 1.7.0 の push モニタを届けるほうが効く**（いま本番に居るのは v1.6.1 で、失敗は誰も見ていない）

**緑（起票せず・次に触るときの申し送り）**

- `Environment.rake?` / `test?` が `rescue false` 修飾子で**例外を丸ごと握っている**。⚠ 環境判定なので実害は薄いが、同じ書き方を増やさないこと
- ⚠ **テストの無い道具が 5 つ**（`mastodon_follow` / `mastodon_media_cleanup` / `reboot_required` / `service_restart` / `help`）。⚠⚠ **`reboot_required` は #122 の当事者**なので、直すときにテストを足す

⚠ **パスワードの扱いは正しかった。**`MYSQL_PWD` / `PGPASSWORD` は環境変数経由で、
**コマンドラインには載っていない**（`/proc/<pid>/environ` は所有者と root しか読めない）。
⚠ ログ側も `/logger/mask_fields` でキーごと落ちており、実機の `command:` 行は `"env":{}` と出る（実測）。

⚠⚠ **1.7.0 は「配布物が変わる」リリース**になった。#68 で periodic スクリプトの中身が変わるので、⚠ **`rake install` を流し直すまで古いスクリプトが残る**（＝ 従来どおり `bundle install` し続ける）。詳細は [deployment.md](deployment.md) の「1.7.0 を配るときに知っておくこと」。

- **#101 は「道具は直さない」で決着。**⚠ **MyISAM を積極的に使う方針は無い**ので、居たらそれ自体が事故 —— 道具が黙って `--lock-tables` へ戻すより、**テーブルを InnoDB へ直すのが正しい対処**。⚠⚠ **実測も是正も writersBASE のインフラ作業**なので、THE-POWERNEWS/writersbase-env#171 として依頼した
  - ⭕ 事前調査では**自分たちのコードに `MyISAM` は 0 件**、テーブルを作るプラグインは `user-access-manager` だけで **`ENGINE=` 句を持たない**（＝ サーバ既定の InnoDB）。⚠ **残る経路は「持ち込んだダンプ」だけ**（`mysqldump` は `ENGINE=MyISAM` をそのまま書き出す）
  - ⚠ 検査クエリは **`table_type = 'BASE TABLE'` で絞ること。**VIEW は `engine` が InnoDB にならないので、付けないと誤検出する
- **#82 は上流（pooza/ginseng-core）へ `CommandLine#secrets` が入ってから。**✅ **2026-09-19 に pooza/ginseng-core#642 として起票し、同日 PR #645 も出した**（`feat/642-mask-command-secrets`・3 コミット・**CI は 3.3 / 3.4 / 4.0 とも緑**・2026-09-20 時点で open）。形は #642 に転記してある（`secrets` / `masked` / `log_exec`。⚠ **既定は空配列なので breaking ではない**）。⚠ **`waiting:pr` はあえて付けていない** —— 忘れたときに誰も動けなくなるため。⚠⚠ **こちらの `Gemfile` は tag 固定なので、PR がマージされても、版を上げる PR を通すまで 1 バイトも届かない。1.7.0 はこれを待たない**
- ⚠ **#104 は「手元で閉じる」を選んだ。**`Config#lookup(key, default)` に寄せ、**fail closed にしたい設定（`postgresql_snapshot` の `target` / `dsn`）は素の `config[...]` のまま**にしてある。⚠⚠ **#82 とは判断が逆**（あちらは本体へ寄せる側）なので、混ぜないこと

### v1.6.1（2026-09-18 タグ）—— ⚠ **いま本番 FreeBSD 3 台で走っているのはこれ**

**当時の最新タグ**（`8737a1c`／公開 2026-09-18）。マイルストーン `1.6.1` の 3 件（#97 / #79 / #87）。⚠⚠ **いまの最新タグは v1.7.0**（上記）だが、⚠ **本番 FreeBSD 3 台で走っているのは依然これ**（vulcan は v1.6.0）。

✅ **shallu / zugoga / gomander が 2026-09-18 に `8737a1c` で走り出した**（実測は 2026-09-19・chubo2#246）。⚠ **3 台とも 8 ソース全て成功・失敗 0**、`.rclonelink` の本数はローカルの symlink 数と完全一致、**破壊的変更（`postgresql_snapshot` の `dsn` 必須化）も通過して健在**。反映の受け皿 **pooza/chubo2#246 は 3/4 で open のまま**。

- 🔴 **vulcan と dev27 は #193 の後に回した。**同日朝の実測で **vulcan の日次は 06:42 → 07:59 の 77 分**、うち `/var/backups/db`（2.3G）だけで 61 分、`/etc` は **exit 1** で終わっている。⚠ **ここへ `.rclonelink` 約 1065 本の一度きりの増分を乗せない**
- ⚠ dev27（ステージング）は実機確認のため手で `8737a1c` に上げてあるが、`bin/chubo` を通していないので**宣言と実機がずれた状態**。揃えるのも #193 の後
- ⚠⚠ **利用側は `git pull --ff-only` で main を追うと未リリースの 1.7.0 を掴む。**v1.6.1 の直後に `cf62324` でバンプしているため。**向こうはタグで指定する運用に変えた**（`git merge --ff-only refs/tags/v1.6.1`）

⚠⚠ **本番で走っている版は、chubo2 のどの道具の視野にも入らない**（2026-09-19 に判明）。periodic の各スクリプトは `cd <チェックアウト> && bin/wb <tool>` で、**チェックアウトを `git pull` した瞬間にその版が本番になる**。cookbook は `git` リソースを持たず、`drift-sweep` は itamae のリソースを・`peer-diff` は宣言を見るだけ。🔴 **「chubo2 の Issue が open ＝ 届いていない」と読まないこと** —— #246 はまさにその形で、起票の翌日には前提が外れていた。**版を知るには実機に ssh して `git describe --tags` する**（手順は chubo2 `docs/infra-common.md` の writersbase-tools 節）。⚠⚠ **`--tags` を省くと必ず失敗する** —— `gh release create` が作るのは**軽量タグ**で、素の `git describe` は注釈付きタグしか見ないため（`fatal: No annotated tags can describe ...`）。⚠⚠ **`--tags` を付けても、ノードがタグを fetch していなければ版の名前は出ない** —— 2026-09-20 の実測で **vulcan は `v1.5.2-48-gd3500df`** と答えた（`d3500df` ＝ v1.6.0 なので**実体は v1.6.0**だが、v1.6.0 / v1.6.1 のタグがローカルに無い）。⚠ **`v<新しい版>-<N>-g<SHA>` と出たら、まず `git fetch --tags` を疑い、SHA でタグと突き合わせること。**（FreeBSD 3 台は `v1.6.1` と答える）

⚠ **3 件とも「黙って落ちているもの」を塞ぐ変更**だった。

- **#97** `--links` … 🔴 **リンクが全ノードでバックアップから落ちていた**（`/etc` だけで vulcan 1063・zugoga 176・gomander 7）。`rclone` は `exit 0` で終わるので誰にも見えていなかった
- **#79** `--single-transaction` … ⚠ `mysqldump` の既定は `--opt` で一貫性は元から取れており、**止まっていたのは書き込みのほう**だった。🔴 代償（MyISAM が無保護）の受け皿は #101
- **#87** `dsn` 必須化 … ⚠⚠ **破壊的変更。**配る前に 4 台の `local.yaml` を見ること。✅ **FreeBSD 3 台は通過して健在**

⚠⚠ **`WRITERSBASE-TOOLS-4` はこの版では止まらない。**原因は Drive API のクォータ（pooza/chubo2#193）。

✅ **配る順番は決着した**（2026-09-19）。`.rclonelink` が一度だけ増える（vulcan 約 1065・zugoga 約 200・gomander 約 40）ため、**#193 の影響下に無い FreeBSD 3 台（rclone 1.75.1・日次は数分）を先行させ、クォータに張り付いている vulcan と dev27 を #193 の後に回した**。⚠ 実測の増分コストは shallu で +35 分程度・一度きり。⚠⚠ **rclone の共有 client_id は 2026 年中に停止する**（rclone 自身が NOTICE で警告）ので、#193 は期限のある作業。

#### リリース前レビュー: 2026-09-18（v1.6.1）

⚠ **赤 0。**黄 2 件は 1.7.0 へ送った（**#104** 設定の「無ければ既定」風の書き方が機能していない／**#105** README の設定の置き場が実態とずれている）。

⚠ **実機確認は dev27 で、実際の periodic スクリプトを cron 相当の非ログインシェルから実行**した（`postgresql_dump` / `access_log_compress` / `reboot_required` とも exit 0）。⚠ `google_drive_backup` は**意図的に回していない**（900 ファイルのアップロードが本番のクォータを食うため、1 リンクの最小構成で挙動だけ実測した）。🔴 `mysql_dump` は**どのノードでも動いていない**ので実機確認できない。

⚠⚠ **この実機確認で、#99 で書いた因果が誤りだと分かった**（下記「反映後に見えた失敗」）。**出荷物のコメントまで誤っていたので #106 で訂正してからタグを打った。**リリース前の実機確認が効いた実例。

### v1.6.0 は出荷済み（2026-09-08 タグ・#71）

⚠ **当時の最新タグ**（`d3500df`／公開 2026-09-08）。⚠⚠ **いまの最新タグと `/package/version` は v1.7.0**（上記）。⚠ **vulcan で走っているのはまだこの版**。v1.5.2（2026-04-12）から 48 コミットぶんで、マイルストーン `1.6.0` の 11 件・#37 Sentry 導入・misskey_emoji_sync 追加・#44 tootctl の login shell 経由をすべて含む。

⚠ **利用側への反映は先に済んでいる**（chubo2 `#214`・2026-09-04 に 9 台すべてを `d3500df` へ／記録は pooza/chubo2 `docs/infra-history.md`）。**タグはその状態を後から確定させたもの**なので、今回は「タグを打ったが 1 台にも届いていない」状態ではない。

⚠⚠ **1.6.0 は「失敗が見えるようになる」リリース。**これまで黙っていた失敗が periodic のメールと Sentry に出始める。**反映後の最初の数回は新しい失敗が増えたように見える**（実際には見えていなかったもの）。⚠ 実際に 2026-09-04 以降、**これまで見えていなかった失敗が Sentry に出ている**（下記「反映後に見えた失敗」）。

⚠⚠ **手でタグを打つ運用は滞留する**（pooza/ginseng-style は 4 gem に計 8 版ぶんの滞留を実測している）。⚠ ただし ginseng-style の `release-tag` composite action は**配布物（gem）を持つリポジトリ向け**で、そのままは載らない。**「version とタグのずれを検査して知らせる」部分だけを採るのが現実的**。⚠ **v1.6.1 では滞留しなかった**（マイルストーン着手時にバンプ → 消化 → 即日タグ）。⚠⚠ **バンプとタグ打ちは 2026-09-18 に委譲された**（バンプは新マイルストーン着手時、タグはリリース手順を通してから）。

### 反映後に見えた失敗（2026-09-20 時点・Sentry `writersbase-tools`）

⚠ **1.6.0 が見せてくれたもの。**Sentry に出ているのは計 7 件。うち 3 件（`-1` / `-2` / `-5`）は疎通確認のために意図的に投げたもので、**実害があるのは次の 3 件**。⚠ **未解決は 6 件**（`-7` だけ 2026-09-18 に resolved）。

- 🔴 **`google_drive_backup` が vulcan で継続失敗**（`WRITERSBASE-TOOLS-4`・計 5 件／初回 2026-09-04・**直近 2026-09-19 07:59 JST**）。⚠⚠ **原因は Drive API のクォータ**（`Error 403 ... rateLimitExceeded`・1 回の実行で 6 回・8 分走って `Transferred: 0 B`）。**pooza/chubo2#193（rclone 既定の共有 client_id）そのもの**で、⚠ **#97 を入れても止まらない。**⚠ 5 件とも **vulcan・`release` は 1.6.0** ＝ **vulcan にだけ v1.6.1 が届いていない**ことの裏づけ（FreeBSD 3 台は 09-18 に上がっている）。⚠ **捕捉時刻は実行の終わり**で、この回は 06:42 に始まり 07:59 に落ちている
- ⚠⚠ **`-4` は 2026-09-20 時点でも計 5 件のまま**（`lastSeen` は 2026-09-18T22:59Z ＝ **09-19 07:59 JST**）。**2026-09-20 に実機で実測した**ところ、`cron.daily` は 09-18 / 09-19 / 09-20 とも **06:42 に走っており**、⚠ **09-20 の回は 5 ソース全成功・6 分 22 秒で終わっている**（09-19 は `/etc` だけ `status: 256` ＝ exit 1・**888 秒**、他 4 ソースは成功）。🔴 **「直った」と読まないこと** —— `rclone.conf` に `client_id` は**無く**（rclone も **1.60.1-DEV** のまま）、**chubo2#193 は 1 行も手が入っていない。**⚠⚠ **共有 client_id のクォータは間欠的**なので、成功する日と失敗する日がある
- 🔴 **失敗した日は、ローカルに 1 行も記録が残らない**（2026-09-20 に実測 → **#119**）。`--verbose` を付けた rclone の stderr が 300 KB を超え、**journald が行ごと捨てる**（FreeBSD の syslogd は **8,087 バイト**で切り詰め）。⚠⚠ **`logger.error` は syslog では `warning`（PRIORITY 4）**になるので、`-p err` / `*.err` で拾う監視は道具の失敗を 1 件も拾わない
- ⚠⚠ **`-4` の原因は Sentry の画面からは読めない。**メッセージが **1024 文字で切り詰められ**、先頭から `Can't follow symlink` の `NOTICE` が埋め尽くすため、**末尾にあるはずの `rateLimitExceeded` が 1 件も見えない**（2026-09-19 に全 5 件の `metadata.value` を実測）。🔴 **Sentry の本文だけを見て原因を決めない** — 実機の rclone ログに当たること。**この見え方こそが「symlink が原因」という誤読（#99・#106 で訂正）を生んだ経路**
- ⚠⚠ **`Can't follow symlink` は失敗の原因ではなかった**（2026-09-18 に実測して訂正）。rclone は **1.60.1 / 1.75.1 とも NOTICE を出して `exit 0`** で終わる。🔴 **つまりリンクは全ノードで黙ってバックアップから落ちていた**（`/etc` だけで vulcan 1063・zugoga 176・gomander 7）。#97 の `--links` は**その静かな欠落**を塞ぐもので、Sentry の失敗を止めるものではない
- ✅ **`postgresql_dump` が shallu / zugoga で継続失敗していた**（`WRITERSBASE-TOOLS-7`・8 件／初回 2026-09-17・最後 2026-09-18・**2026-09-18 に解消**）。`zstd: error 25 : Write error : No space left on device`。⚠⚠ **道具の側は正しい** — 失敗を拾い（#63）、壊れた `.zst` を消し、**ローテーションを走らせずに**（#62）終わっており、既存の 7 世代は無事。原因は 2026-09-13 の backups 縮小（pooza/chubo2#233）で撮った `zfs` スナップショット `@move1` / `@move2` が残り、**保持期間を過ぎて消したはずのダンプを掴んだまま** 16.5G / 11.9G を占めていたこと。⚠ 起票は pooza/chubo2#242（直すのは向こうのディスク）。**ただし 09-17 / 09-18 のダンプは取れていない**。✅ **2026-09-18 に chubo2#242 がクローズ**され、`-7` も **resolved**（`lastSeen` 09-17T19:44Z 以降は再発なし）。⚠ resolve は chubo2 の `sentry-resolve.rb`（#242 の副産物）で Issue 単位に打てる
- ⚠ **`mastodon_follow` が `account: info` で `No such account`**（`WRITERSBASE-TOOLS-3`・1 回・2026-09-04）。⚠ 2026-09-15 の棚卸しでは意図的な 3 件にも実害にも数えていなかった**取りこぼし**。実機の設定を見て、消えたアカウントなら node yaml から外す
- ⚠ **`bin/wb <存在しない名前>` が `NameError: uninitialized constant WritersBase::ConfigTool` として Sentry に載る**（`WRITERSBASE-TOOLS-6`・1 回・2026-09-12）。`bin/wb.rb` の集約点がツールの失敗と打ち間違いを区別しないため。**害は無いがノイズになる**

⚠⚠ **道具の側は #113 で Uptime Kuma の push へ送るようになったが、これらの失敗はまだ拾われていない**（#91 は ✅ だが **1.7.0 が未出荷**で、届いているのは v1.6.1 まで）。上の 🔴 も、ダッシュボードを開くまで誰も気づいていなかった。**「Sentry に出ている」は「気づかれている」ではない**。⚠ `-7` は **2 日間・本番 2 台でバックアップが取れていない**状態を誰も知らなかった。**monit 側にも同じ穴があった**（89% / 92% で鳴っていない・pooza/chubo2#242）。✅ **monit 側は 2026-09-18 に塞がった**（pooza/chubo2#244 ＝ alert を Uptime Kuma の push モニタへ繋いだ）。⚠ **利用側の受け皿は pooza/chubo2#248**（open・⚠ **chubo2#227 から「Ubuntu の `reboot_required` の出口」も引き継がれている**）。

⚠ **Sentry の件数をそのまま実行回数と読まない。**`-7` の 8 件は **2 台 × 2 日 × 1 日 2 回**だった。`periodic daily` が anacron と cron の両方から走っていて、**`daily` に並べた道具が 1 日 2 回実行されている**（pooza/chubo2#243）。⚠⚠ **起票時の前提は 2 つとも外れていた**（2026-09-18 に chubo2 側で実測）—— **「3 台」ではなく FreeBSD 10 台すべて**、**daily だけでなく weekly / monthly も二重**。✅ **anacron ごと外して解消済み**（chubo2 `8f3d37b`・**chubo2#243 は 2026-09-18 にクローズ**）。⚠ **解消は 09-18 以降の話**なので、それ以前の件数は依然 2 倍で読む。

⚠⚠ **1 日 1 回にはなったが、着火時刻は今も固定ではない**（2026-09-19 に chubo2 側で実測。shallu の daily は 09-18 が 00:10・09-19 が **03:27** と 3 時間以上ずれる）。🔴 **「何時に終わるか」を前提にした監視を作らないこと** —— #91 で入れた Uptime Kuma の push モニタの interval は、これを織り込んだ値にする（受け皿は pooza/chubo2#248）。⚠ hourly（`postgresql_snapshot` / `mastodon_follow`）は数十秒で終わるので素直でよい。

### リリース前レビュー

ginseng-style が最低限として置く 3 観点に、本プロジェクト固有の観点を足す。

| 観点 | 焦点 |
| --- | --- |
| セキュリティ | 認証情報の取り扱い、Sentry の `scrub_patterns`、コマンドラインへの秘密の露出（`MYSQL_PWD` / `PGPASSWORD`） |
| エラー処理・観測性 | ⚠ **外部コマンドの終了ステータスを本当に拾っているか**（`zfs destroy` の取りこぼし前例）、ログが「やった」と嘘をつかないか |
| コーディングスタイル・規約整合性 | RuboCop、ginseng-style の表記規約 |
| **破壊的操作** | ⚠⚠ **`rclone sync` / `zfs destroy` / `rm` の宛先と保持期間。**既定値のまま別ノードへ写すと消してはいけないものを消す |
| **設定の既定値** | ⚠ 配列キーは**置換**される（[deployment.md](deployment.md)）。既定を変えるときは、利用側の node yaml が上書きしている前提で影響を見る |

分類は 赤（必修）／黄（余力があれば）／緑（送り）。

#### 外部レビュアー（OpenAI Codex）

PR に `@codex review` と書くとレビューが返る。⚠⚠ **PR を開いた時点でも走ることがあるが、当てにしないこと**（2026-09-18 の実測: #98 は開いた 35 秒後に自動で走ったが、**#100 / #102 は走らなかった**）。**確実なのは明示的に投げること。**⚠ **人のレビューの代わりではなく、上の観点を回す前の当て木**として使う。

- ⚠⚠ **GitHub App の導入は org ごと。**pooza 個人の repo で動いていても、**THE-POWERNEWS の repo では別に入れる必要がある**（2026-09-18 に導入。それまで #94 の `@codex review` は 3 日間**無反応**だった）
- ⚠ **App を入れただけでは足りない。**repo ごとに https://chatgpt.com/codex/cloud/settings/environments で環境を作る。未作成なら bot が `To use Codex here, create an environment for this repo` と返す（pooza/ginseng-style#73 / #77 の実績）
- ⚠ **無反応と「環境が無い」は別物。**何も返らないときは **App が届いていない**（org 未導入・repo 未選択）
- ⚠⚠ **指摘の有無で返り方が違う。**指摘があれば **review ＋ 行コメント**（`pulls/{n}/reviews` と `pulls/{n}/comments`）、無ければ **`Didn't find any major issues.` という PR コメント**（`issues/{n}/comments`）。⚠ **`reviews` だけを見ていると「返ってきていない」と誤読する**（2026-09-18 に実測）。応答は依頼から 2〜3 分
- ⚠⚠ **差分だけを見た指摘は意図を誤読する。**#94（`branch: main` → `tag: v1.23.7`・**指す SHA は同じ**）のような「更新ではなく記録」の PR では特に。**返ってきた指摘も赤／黄／緑に仕分けてから扱う**

### リリース前レビューの記録: 2026-09-02（初回）

`main`（v1.5.2 + 20 コミット）の全コードを対象に、上表の 5 観点で実施した。**赤 6・黄 6・緑 3。**マイルストーン `1.6.0` に赤と小粒の黄を割り当てた（重み 13）。

⚠⚠ **赤 6 件のうち 4 件が「失敗が成功に見える」型だった。**外部コマンドへ shell out する道具の集まりなので、**終了ステータスの扱いが割れていること自体が最大の欠陥**（`Tool#compress` / `GoogleDriveBackupTool` / `RsyncBackupTool` / `MastodonTootctl` は見ているが、`zfs` / `service` / `pg_dump` / `mysqldump` は見ていない）。

| | Issue | 観点 | 状態（2026-09-15） |
| --- | --- | --- | --- |
| 🔴 赤 | [#61](https://github.com/THE-POWERNEWS/writersbase-tools/issues/61) スナップショットの掃除が「日時を持たない名前」を無条件に削除する | 破壊的操作 | ✅ #76 |
| 🔴 赤 | [#62](https://github.com/THE-POWERNEWS/writersbase-tools/issues/62) ダンプの失敗を検出できず、直後のローテーションで正常なダンプを消す | 破壊的操作 | ✅ #78 |
| 🔴 赤 | [#63](https://github.com/THE-POWERNEWS/writersbase-tools/issues/63) 外部コマンドの終了ステータスを見ていない箇所がある | エラー処理 | ✅ #77 |
| 🔴 赤 | [#64](https://github.com/THE-POWERNEWS/writersbase-tools/issues/64) ツールが握った失敗が Sentry に届かず、終了コードも 0 | エラー処理 | ✅ #80 |
| 🔴 赤 | [#65](https://github.com/THE-POWERNEWS/writersbase-tools/issues/65) misskey_emoji_sync の webhook URL がログに平文で出る | セキュリティ | ✅ #81 ⚠ **webhook の再発行が要る** |
| 🔴 赤 | [#72](https://github.com/THE-POWERNEWS/writersbase-tools/issues/72) `rake install` は一部が失敗しても成功として終わる | エラー処理 | ✅ #83 |
| 🟡 黄 | [#66](https://github.com/THE-POWERNEWS/writersbase-tools/issues/66) `/logger/mask_fields` 未定義でマスクが丸ごと無効 | セキュリティ | ✅ #85（ginseng-core の bump 込み） |
| 🟡 黄 | [#67](https://github.com/THE-POWERNEWS/writersbase-tools/issues/67) 他ノードで黙って失敗する既定値 | 設定の既定値 | ✅ #88（⚠ dsn だけ #87 へ送り） |
| 🟡 黄 | [#68](https://github.com/THE-POWERNEWS/writersbase-tools/issues/68) periodic が毎回 root で `bundle install` する | セキュリティ | ✅ **1.7.0**（`bundle check` へ／⚠ 配るには `rake install` の流し直しが要る） |
| 🟡 黄 | [#69](https://github.com/THE-POWERNEWS/writersbase-tools/issues/69) CI がテストを実行していない | 規約整合性 | ✅ #86 |
| 🟡 黄 | [#70](https://github.com/THE-POWERNEWS/writersbase-tools/issues/70) ginseng-style をタグではなく SHA で固定する | 規約整合性 | ✅ #84 |
| 🟡 黄 | [#71](https://github.com/THE-POWERNEWS/writersbase-tools/issues/71) v1.5.2 から 20 コミットが未リリース | 規約整合性 | ✅ **v1.6.0**（2026-09-08 タグ） |

**緑（起票せず・次に触るときの申し送り）** — 3 件とも 1.6.0 で処理済み

- ✅ 「削除対象ファイルなし」を error レベルで出していた件 → #78 で info へ。⚠ **`WritersBase::Logger#warn`（error への転送）は #85 で撤去**したので、いまは `warn` も素の warn
- ✅ `dump` の `ensure logger.info('ダンプ完了')` が失敗時にも「完了」と出す件 → #78
- ⏳ `mysqldump` の `--single-transaction` → **#79 として起票**（⏳ open・1.6.0 には載らず）

⚠ **レビューはサブエージェントの並列ではなく、単一セッションで全ファイルを読んで実施した。**規模（app/lib 配下 30 ファイル弱）では並列にする利得が無いため。**次回も同じでよい。**

⚠ **赤の再発検査は「その場の回帰テスト」までしか入っていない**（#61 の `obsolete?`、#62 の `pipefail_args`、#63 の `command_error`、#64 の `failed?`、#65 のログのマスク、#66 の `_mask_error`、#72 の未対応プラットフォーム）。**新しい道具を足したときに同じ轍を踏まない仕掛けは無い**ので、次のレビューでもここは人が見る。

### 1.6.0 で分かった、レビューでは見えていなかったこと

- ⚠⚠ **`Ginseng::CommandLine#status` は `Process::Status#to_i` の生値**で終了コードではない（`exit 3` は **768**）。**ログの `status` をそのまま終了コードと読まない**
- ⚠⚠ **`WritersBase::Logger#mask` が `Ginseng::Masking#mask(arg)` と名前衝突していた。**ginseng-core を上げた瞬間に fail closed で**全ログが `_mask_error` になる**形（#85 で実測）。**正本にある名前で独自メソッドを生やさないこと**
- ⚠ **Dependabot の PR は古い main から切られていることがある。**#57 / #58 はいずれも Sentry 導入前のブランチで、`Gemfile.lock` の突き合わせが怪しかった。**取り直したほうが安全**

### リリース前の実機確認

⚠⚠ **CI の緑はリリース判断の根拠にならない。**#69 で CI は `rake lint` ＋ `rake test` を回すようになったが、**ツールの本体は外部コマンド（`zfs` / `rclone` / `pg_dump` / `tootctl`）への shell out** なので、CI で検証できる範囲は限られる。⚠ 前提を満たさないケースは `disable?` で **omission** になる（**「実行されていない」が緑に埋もれないよう、件数がサマリに出る**）。

- 手元・ステージングで `bin/wb <ツール名>` を単発実行して確かめる（`bin/wb help` で一覧）
- テストは `bundle exec rake test`（全件）または `bin/test.rb <ケース名>`（単体）
- cron から走る道具なので、**非ログインシェル相当（`env -i`）で確かめる**。⚠ ログインシェル前提の rbenv 初期化に依存している経路がある（#44）
- ステージングに載せていない／載せられないタスクがある（`postgresql_snapshot` は専用 ZFS データセット、`mastodon_follow` は実アカウントを触る）。**載せられないものは本番で慎重に一度手で回す**

## 進捗の同期手順

会話の最初に「進捗を同期してください」等の指示があった場合に実行する。⚠ pooza/mulukhiya-toot-proxy の手順を、本プロジェクトの規模に合わせて縮めたもの。

1. **ガイドの読み込み** — `docs/CLAUDE.md` を読む。`MEMORY.md` は自動ロードされるので、両者の整合性を意識する
2. **リモートとの同期** — `git fetch origin` を**最初に必ず実行**（リモートが正本）。`git log HEAD..origin/main --oneline` / `gh issue list --state open` / `gh pr list --state open`
3. **Dependabot** — `gh api repos/THE-POWERNEWS/writersbase-tools/dependabot/alerts` で open アラートを確認
4. **レビューコメント** — 直近マージの PR に未消化のコメントが無いか。⚠ **`pulls/{n}/comments` は行に紐づくものしか返さない。**PR 本体のコメントは `issues/{n}/comments` で別に取る。⚠ **bot だけを見ない** — 他リポジトリのセッションが `pooza` として申し送りを置くことがある
5. **Sentry** — `sentry-cli issues list` で未解決イシューを確認する。⚠ **DSN が配られているのは一部ノードだけ**で、しかも最新版が動いていないノードがある（[positioning.md](positioning.md)）。**「0 件」を「失敗が無い」と読まない**
6. **利用側の同期** — 本プロジェクト固有。⚠ **こちらが当番のように担当しない**が、**要求の出どころなので見る**
   - pooza/chubo2 … `git fetch` して `docs/infra-common.md` の「writersbase-tools」節・`docs/infra-misskey.md` の periodic 節に変更が無いか。open Issue のうち本ツールに依存するもの（バックアップ・スナップショット系）
   - THE-POWERNEWS/writersbase-env … `config/platform/ubuntu.yaml` の `tools` と、#137（tools を最新版へ上げる）の進捗
   - pooza/ginseng-style … ⚠ **専任セッションの持ち物なので棚卸ししない。**見るのは**こちらのピンのずれ**（`Gemfile` の参照が正本の現行版から何版遅れているか）だけ
   - ⚠⚠ **`ginseng-core` は git 参照なので、向こうが直しても `bundle update` するまで 1 バイトも届かない。**「Issue が close された」は取り込み済みを意味しない
7. **マイルストーンとバージョン** — open Issue の状態と `/package/version`・最新タグのずれを確認する
8. **`MEMORY.md` の更新** — 上記で検出した差分を反映する
9. **報告** — 現在のブランチ・状態、各確認項目の結果をまとめて報告する

## 情報の記載先ルール

- **課題・タスク** → GitHub Issue。⚠ **どのリポジトリに立てるかは「直すコードがどこにあるか」で決める**
  - ツール本体・設定の既定値・`Installer` → THE-POWERNEWS/writersbase-tools
  - 配備・node の設定・cookbook（`writersbase_tools`） → pooza/chubo2（実装が chubo-core でも起票は chubo2）
  - writersBASE 側の配備・`tools` cookbook → THE-POWERNEWS/writersbase-env
  - ⚠⚠ **writersBASE のインフラ作業そのもの**（DB の調査・是正、実機での確認）も **THE-POWERNEWS/writersbase-env へ「依頼」の形で起票する。**⚠ こちらの Issue に実作業を溜めない（#101 → writersbase-env#171 が実例）
  - 規約・RuboCop 設定 → pooza/ginseng-style
- **プロジェクトで共有すべき知見** → `docs/` 以下（git 管理下）。⚠ Issue とセッションメモリだけで済ませない
- **インフラの現況・手順・罠** → pooza/chubo2 の `docs/infra-note.md` / `docs/infra-history.md`。⚠ **こちらの docs に写しを作らない**（正本を 2 つにしない）
- **進捗の同期** → `MEMORY.md` だけでなく `docs/CLAUDE.md` も更新する。⚠ **特にリリース済みバージョンの反映**を忘れない

## push 前の必須手順

1. `bundle exec rake lint`（lint が通ること）
2. `bundle exec rake test`（テストが通ること。⚠ omission の件数も見る）
3. 触ったツールを `bin/wb <ツール名>` で実行
4. その上で push
