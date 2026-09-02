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
- ⚠⚠ **`Gemfile` の `ginseng-style` は現在 `tag: 'v1.1.4'` で固定されている。**正本の指示は **SHA 固定**（タグは付け替えられるため。pooza/ginseng-style#75）で、正本の現行版は **v1.1.12**。**tag → SHA へ、かつ版を上げる**必要がある（#56 / #58 が open）
- 本リポジトリは CI に ginseng-style の composite action（`ruby-check`）を使っていない。⚠ 使うなら**参照は SHA で固定し、`Gemfile` と揃える**

## ブランチ

⚠ **`main` だけを使う。**feature ブランチを切って `main` へ直接 PR を出す。

- 命名は `fix/<issue>-<slug>` / `feat/<issue>-<slug>` / `chore/<issue>-<slug>`（実績は `feature/<issue>-<slug>` も混在）
- ⚠⚠ **`origin/develop` は死んでいる**（2026-09-02 実測: `main` に対し **behind 33 / ahead 0**、直近 8 本のマージはすべて feature ブランチ → `main`）。**現行と誤読して宛先にしないこと。**削除するかは別途判断
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

### 🔴 現在 20 コミットが未リリース（2026-09-02・#71）

最新タグは **v1.5.2**（2026-04-12）、`/package/version` も **1.5.2** のまま。以降に **#37 Sentry 導入**・**misskey_emoji_sync 追加**・**#44 tootctl の login shell 経由**などが `main` に載っている。

⚠⚠ **手でタグを打つ運用は滞留する**（pooza/ginseng-style は 4 gem に計 8 版ぶんの滞留を実測している）。⚠ ただし ginseng-style の `release-tag` composite action は**配布物（gem）を持つリポジトリ向け**で、そのままは載らない。**「version とタグのずれを検査して知らせる」部分だけを採るのが現実的**。

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

### リリース前レビューの記録: 2026-09-02（初回）

`main`（v1.5.2 + 20 コミット）の全コードを対象に、上表の 5 観点で実施した。**赤 6・黄 6・緑 3。**マイルストーン `1.6.0` に赤と小粒の黄を割り当てた（重み 13）。

⚠⚠ **赤 6 件のうち 4 件が「失敗が成功に見える」型だった。**外部コマンドへ shell out する道具の集まりなので、**終了ステータスの扱いが割れていること自体が最大の欠陥**（`Tool#compress` / `GoogleDriveBackupTool` / `RsyncBackupTool` / `MastodonTootctl` は見ているが、`zfs` / `service` / `pg_dump` / `mysqldump` は見ていない）。

| | Issue | 観点 |
| --- | --- | --- |
| 🔴 赤 | [#61](https://github.com/THE-POWERNEWS/writersbase-tools/issues/61) スナップショットの掃除が「日時を持たない名前」を無条件に削除する | 破壊的操作 |
| 🔴 赤 | [#62](https://github.com/THE-POWERNEWS/writersbase-tools/issues/62) ダンプの失敗を検出できず、直後のローテーションで正常なダンプを消す | 破壊的操作 |
| 🔴 赤 | [#63](https://github.com/THE-POWERNEWS/writersbase-tools/issues/63) 外部コマンドの終了ステータスを見ていない箇所がある | エラー処理 |
| 🔴 赤 | [#64](https://github.com/THE-POWERNEWS/writersbase-tools/issues/64) ツールが握った失敗が Sentry に届かず、終了コードも 0 | エラー処理 |
| 🔴 赤 | [#65](https://github.com/THE-POWERNEWS/writersbase-tools/issues/65) misskey_emoji_sync の webhook URL がログに平文で出る | セキュリティ |
| 🔴 赤 | [#72](https://github.com/THE-POWERNEWS/writersbase-tools/issues/72) `rake install` は一部が失敗しても成功として終わる | エラー処理 |
| 🟡 黄 | [#66](https://github.com/THE-POWERNEWS/writersbase-tools/issues/66) `/logger/mask_fields` 未定義でマスクが丸ごと無効 | セキュリティ |
| 🟡 黄 | [#67](https://github.com/THE-POWERNEWS/writersbase-tools/issues/67) 他ノードで黙って失敗する既定値 | 設定の既定値 |
| 🟡 黄 | [#68](https://github.com/THE-POWERNEWS/writersbase-tools/issues/68) periodic が毎回 root で `bundle install` する | セキュリティ |
| 🟡 黄 | [#69](https://github.com/THE-POWERNEWS/writersbase-tools/issues/69) CI がテストを実行していない | 規約整合性 |
| 🟡 黄 | [#70](https://github.com/THE-POWERNEWS/writersbase-tools/issues/70) ginseng-style をタグではなく SHA で固定する | 規約整合性 |
| 🟡 黄 | [#71](https://github.com/THE-POWERNEWS/writersbase-tools/issues/71) v1.5.2 から 20 コミットが未リリース | 規約整合性 |

**緑（起票せず・次に触るときの申し送り）**

- `WritersBase::Logger#warn` は `error` へ転送されるので、`delete_old_files` の「削除対象ファイルなし」が**正常な状態なのに error レベル**で出る
- `dump` の `ensure logger.info('ダンプ完了')` は**失敗時にも「完了」と出す**
- `mysqldump` に `--single-transaction` が無い。InnoDB では一貫性のない写しになりうる

⚠ **レビューはサブエージェントの並列ではなく、単一セッションで全ファイルを読んで実施した。**規模（app/lib 配下 30 ファイル弱）では並列にする利得が無いため。**次回も同じでよいが、`赤` の再発検査だけは自動化を検討する**（#69 のテスト整備に載せる）。

### リリース前の実機確認

⚠⚠ **CI の緑はリリース判断の根拠にならない。**CI は `bundle exec rubocop` しか回しておらず、**テスト（`test/` の 3 本）を実行していない**。ツールの本体は外部コマンド（`zfs` / `rclone` / `pg_dump` / `tootctl`）への shell out なので、CI で検証できる範囲はほとんど無い。

- 手元・ステージングで `bin/wb <ツール名>` を単発実行して確かめる（`bin/wb help` で一覧）
- テストは `bin/test.rb <ケース名>`。⚠ **`rake test` は無い**
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
  - 規約・RuboCop 設定 → pooza/ginseng-style
- **プロジェクトで共有すべき知見** → `docs/` 以下（git 管理下）。⚠ Issue とセッションメモリだけで済ませない
- **インフラの現況・手順・罠** → pooza/chubo2 の `docs/infra-note.md` / `docs/infra-history.md`。⚠ **こちらの docs に写しを作らない**（正本を 2 つにしない）
- **進捗の同期** → `MEMORY.md` だけでなく `docs/CLAUDE.md` も更新する。⚠ **特にリリース済みバージョンの反映**を忘れない

## push 前の必須手順

1. `bundle exec rubocop`（lint が通ること）
2. 触ったツールを `bin/wb <ツール名>` で実行、または `bin/test.rb <ケース名>`
3. その上で push
