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
- ⚠ `ginseng-core` は `Gemfile` では ref を指定せず、`Gemfile.lock` の revision で固定している（現在 **1.23.7 / `b6e736d`**）。⚠ **これを `tag: v1.23.7` へ移す PR #94 が open**（pooza/ginseng-style#103 のロールアウト）。revision は 1 ビットも動かない「記録」で、狙いは**破綻の受け皿を無関係な `bundle update` から版を上げる PR の CI へ移すこと**

### 保留中の依存の更新

- ⏳ **`sentry-ruby` 7.0.0（PR #93）は意図的に保留**。tools が触る API（`Sentry.init` / `capture_exception` / `before_send` / `close`）は無傷だが、7.0.0 で **logs / metrics が既定で有効**になり（`enable_logs` / `enable_metrics` は撤去）、`send_default_pii` が deprecated（`data_collection` へ）。⚠⚠ **1.6.0 は「失敗が Sentry に出るようになる」リリースなので、送信経路の挙動が黙って変わるのは最も避けたい**。dev1 で例外を 1 件飛ばし `env` 付きで着弾するのを確認してからマージする。**閉じないこと**

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

### v1.6.0 は出荷済み（2026-09-08 タグ・#71）

**最新タグは v1.6.0**（`d3500df`／公開 2026-09-08）。`/package/version` も **1.6.0**。v1.5.2（2026-04-12）から 48 コミットぶんで、マイルストーン `1.6.0` の 11 件・#37 Sentry 導入・misskey_emoji_sync 追加・#44 tootctl の login shell 経由をすべて含む。

⚠ **利用側への反映は先に済んでいる**（chubo2 `#214`・2026-09-04 に 9 台すべてを `d3500df` へ／記録は pooza/chubo2 `docs/infra-history.md`）。**タグはその状態を後から確定させたもの**なので、今回は「タグを打ったが 1 台にも届いていない」状態ではない。

⚠⚠ **1.6.0 は「失敗が見えるようになる」リリース。**これまで黙っていた失敗が periodic のメールと Sentry に出始める。**反映後の最初の数回は新しい失敗が増えたように見える**（実際には見えていなかったもの）。⚠ 実際に 2026-09-04 以降、**これまで見えていなかった失敗が Sentry に出ている**（下記「反映後に見えた失敗」）。

⚠⚠ **手でタグを打つ運用は滞留する**（pooza/ginseng-style は 4 gem に計 8 版ぶんの滞留を実測している）。⚠ ただし ginseng-style の `release-tag` composite action は**配布物（gem）を持つリポジトリ向け**で、そのままは載らない。**「version とタグのずれを検査して知らせる」部分だけを採るのが現実的**。⚠ v1.6.0 の後も `main` は 2 コミット進んでおり（ginseng-core の bump）、**version は 1.6.0 のまま**。次のマイルストーンに着手した時点でバンプする。

### 反映後に見えた失敗（2026-09-18 時点・Sentry `writersbase-tools`）

⚠ **1.6.0 が見せてくれたもの。**Sentry に出ているのは計 7 件。うち 3 件（`-1` / `-2` / `-5`）は疎通確認のために意図的に投げたもので、**実害があるのは次の 3 件**。

- 🔴 **`google_drive_backup` が Misskey ノードで継続失敗**（`WRITERSBASE-TOOLS-4`・3 回／初回 2026-09-04・直近 2026-09-14）。`src: /home/misskey/repos/misskey` の `.nvmrc` がシンボリックリンクで、`rclone sync` が `Can't follow symlink without -L/--copy-links` を出して非ゼロで終わる。⚠ **`--links` / `--copy-links` を渡すか、リンクを `excludes` に落とすかの判断が要る**（前者は宛先の中身が変わるので、`rclone sync` の宛先削除と合わせて見ること）。⚠ 対象 src を絞る話は pooza/chubo2#194 と重なる
- 🔴 **`postgresql_dump` が shallu / zugoga で継続失敗**（`WRITERSBASE-TOOLS-7`・8 件／初回 2026-09-17・直近 2026-09-18）。`zstd: error 25 : Write error : No space left on device`。⚠⚠ **道具の側は正しい** — 失敗を拾い（#63）、壊れた `.zst` を消し、**ローテーションを走らせずに**（#62）終わっており、既存の 7 世代は無事。原因は 2026-09-13 の backups 縮小（pooza/chubo2#233）で撮った `zfs` スナップショット `@move1` / `@move2` が残り、**保持期間を過ぎて消したはずのダンプを掴んだまま** 16.5G / 11.9G を占めていたこと。⚠ 起票は pooza/chubo2#242（直すのは向こうのディスク）。**ただし 09-17 / 09-18 のダンプは取れていない**
- ⚠ **`mastodon_follow` が `account: info` で `No such account`**（`WRITERSBASE-TOOLS-3`・1 回・2026-09-04）。⚠ 2026-09-15 の棚卸しでは意図的な 3 件にも実害にも数えていなかった**取りこぼし**。実機の設定を見て、消えたアカウントなら node yaml から外す
- ⚠ **`bin/wb <存在しない名前>` が `NameError: uninitialized constant WritersBase::ConfigTool` として Sentry に載る**（`WRITERSBASE-TOOLS-6`・1 回・2026-09-12）。`bin/wb.rb` の集約点がツールの失敗と打ち間違いを区別しないため。**害は無いがノイズになる**

⚠⚠ **通知経路は依然として無い**（#91）。上の 🔴 も、ダッシュボードを開くまで誰も気づいていなかった。**「Sentry に出ている」は「気づかれている」ではない**。⚠ `-7` は **2 日間・本番 2 台でバックアップが取れていない**状態を誰も知らなかった。**monit 側にも同じ穴がある**（89% / 92% で鳴っていない・pooza/chubo2#242）。

⚠ **Sentry の件数をそのまま実行回数と読まない。**`-7` の 8 件は **2 台 × 2 日 × 1 日 2 回**だった。`periodic daily` が anacron と cron の両方から走っていて、**`daily` に並べた道具が 1 日 2 回実行されている**（pooza/chubo2#243・FreeBSD 3 台）。

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

PR に `@codex review` と書くとレビューが返る。⚠ **人のレビューの代わりではなく、上の観点を回す前の当て木**として使う。

- ⚠⚠ **GitHub App の導入は org ごと。**pooza 個人の repo で動いていても、**THE-POWERNEWS の repo では別に入れる必要がある**（2026-09-18 に導入。それまで #94 の `@codex review` は 3 日間**無反応**だった）
- ⚠ **App を入れただけでは足りない。**repo ごとに https://chatgpt.com/codex/cloud/settings/environments で環境を作る。未作成なら bot が `To use Codex here, create an environment for this repo` と返す（pooza/ginseng-style#73 / #77 の実績）
- ⚠ **無反応と「環境が無い」は別物。**何も返らないときは **App が届いていない**（org 未導入・repo 未選択）
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
| 🟡 黄 | [#68](https://github.com/THE-POWERNEWS/writersbase-tools/issues/68) periodic が毎回 root で `bundle install` する | セキュリティ | ⏳ **open**（1.6.0 には載らず） |
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
  - 規約・RuboCop 設定 → pooza/ginseng-style
- **プロジェクトで共有すべき知見** → `docs/` 以下（git 管理下）。⚠ Issue とセッションメモリだけで済ませない
- **インフラの現況・手順・罠** → pooza/chubo2 の `docs/infra-note.md` / `docs/infra-history.md`。⚠ **こちらの docs に写しを作らない**（正本を 2 つにしない）
- **進捗の同期** → `MEMORY.md` だけでなく `docs/CLAUDE.md` も更新する。⚠ **特にリリース済みバージョンの反映**を忘れない

## push 前の必須手順

1. `bundle exec rake lint`（lint が通ること）
2. `bundle exec rake test`（テストが通ること。⚠ omission の件数も見る）
3. 触ったツールを `bin/wb <ツール名>` で実行
4. その上で push
