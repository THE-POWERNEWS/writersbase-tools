---
name: sync
description: セッション開始時の進捗同期。「進捗を同期してください」「同期して」などで起動する。リモート・Dependabot・直近の PR のコメント・Sentry・利用側（chubo2 / writersbase-env）・ginseng-* のピン・Ruby 本体の版・マイルストーンを確認して報告する。
---

# セッション開始時の同期手順

🔴 **会話の最初に「進捗を同期してください」等の指示があったら、この手順を実行する。**

⚠ **この手順の正本はこのファイル**（#215 で `docs/CLAUDE.md` から移した）。手順の中のコマンドは `scripts/` に同梱してあり、**リポジトリのルートから実行する**。pooza/mulukhiya-toot-proxy の手順を、本プロジェクトの規模に合わせて縮めたもの。

🔴 **読むだけの手順なので自動起動にしてある**（[ginseng-style の docs/skills.md](https://github.com/pooza/ginseng-style/blob/main/docs/skills.md)）。⚠⚠ **外へ書くもの（Issue の起票・コメント・docs の更新の PR・Sentry の resolve）は、報告して判断を仰いでから行う。**2026-11-07 の同期では docs の手順を読みながら回して、報告の前に起票（#213）と PR（#214）まで進めた。⚠ 例外は手元のメモリ（`MEMORY.md`）だけ

## 1. ガイドの読み込み

- `docs/CLAUDE.md` を読む（規約の差分・リリースの記録・情報の記載先の正本）。`MEMORY.md` は自動ロードされるので、両者の整合性を意識する
- 前回の同期の日付は `docs/CLAUDE.md` の記録（「反映後に見えた失敗（YYYY-MM-DD 時点…）」など）から取る。手順 6 の `consumers.sh` に渡す

## 2. リモートとの同期

- `git fetch origin` を**最初に必ず実行**（リモートが正本。手元の状態を信用しない）
- `git status -sb` / `git log HEAD..origin/main --oneline`
- `gh issue list --state open` / `gh pr list --state open`
- ⚠ **他のセッションの PR が開いていることがある**（2026-11-07 の #212）。中身と CI・Codex の結果だけ見て報告し、こちらからはマージしない

## 3. Dependabot

- `gh api repos/THE-POWERNEWS/writersbase-tools/dependabot/alerts --jq '.[]|select(.state=="open")|"\(.number) \(.dependency.package.name) \(.security_advisory.ghsa_id)"'`
- ⚠ 開いたままの依存の PR は、`docs/CLAUDE.md` の「保留中の依存の更新」と突き合わせる（sentry-ruby 7.x は意図的に保留）

## 4. 直近の PR のコメント

```sh
.claude/skills/sync/scripts/codex_channels.sh          # 直近にマージされた 5 本
.claude/skills/sync/scripts/codex_channels.sh 212 214  # 番号を指定
```

- ⚠ **Codex の結果は 4 経路で来る**（review・インライン・PR 本体のコメント・PR へのリアクション）。**指摘が無ければ PR コメントか 👍 だけ**なので、`pulls/{n}/comments` だけを見て「来ていない」と読まない
- ⚠ インラインの Codex の指摘で返信が無いものは `🔴 未処理` と出る。対応が要るかを判断する
- ⚠ **bot だけを見ない。**他リポジトリのセッションが `pooza` として申し送りを置くことがあるので、人のコメントは全文を出している

## 5. Sentry

- `sentry-cli issues list -p writersbase-tools`（⚠ `-p` を省くと既定のモロヘイヤが出る）
- ⚠ **DSN が配られているのは一部ノードだけ。**また、Ruby が起動しない止まり方（`bundle check` の失敗・native 拡張が読めない）は Sentry に出ない（`docs/CLAUDE.md` の「反映後に見えた失敗」）。**「0 件」を「失敗が無い」と読まない**
- ⚠ 見出しは 1024 文字で切れる。原因を読むときはイベント API（`/issues/{id}/events/?full=true`）で exception の value を取る

## 6. 利用側と上流

⚠ **利用側の作業はこちらが当番のように担当しない**が、**要求の出どころなので見る**。

```sh
.claude/skills/sync/scripts/consumers.sh <前回の日付 YYYY-MM-DD>
```

- pooza/chubo2 … platform yaml の `writersbase_tools.version`（＝ 配った版）・tools に触れたコミット・`docs/infra-common.md` / `docs/infra-misskey.md` の変更・open / 閉じた Issue。⚠ チェックアウトは `CHUBO2_DIR`（既定 `~/repos/chubo2`）。⚠⚠ **反映の受け皿が閉じていたら、`docs/CLAUDE.md` のその版の見出しを「配った」に直す**
- THE-POWERNEWS/writersbase-env … `config/platform/ubuntu.yaml` の変更と、tools に関わる open Issue（#137 など）。⚠ env は版を宣言していないので、どの版が動いているかはここからは分からない
- ⚠⚠ **`🔴 取得失敗` の行が出たら、その範囲は「0 件」ではなく「未確認」として報告する**

### ginseng-* のピン

🔴 **毎回必ず回す。**ginseng-* は Dependabot から外してあるので（#139）、**ずれに気づく経路はここだけ**。

```sh
ruby .claude/skills/sync/scripts/ginseng_pin_drift.rb
```

- 「ずれ」と出たら、gem ごとに**すぐ／次のマイルストーン／見送り**を決め、リリースノートの「破壊的変更」「利用側で必要なこと」と tools が触る API を突き合わせて報告する。起票（#213 の形）は判断を仰いでから
- ⚠ pooza/ginseng-style は**専任セッションの持ち物なので棚卸ししない。**見るのはこちらのピンのずれだけ
- ⚠⚠ **`ginseng-core` は git 参照なので、向こうが直しても `bundle update` するまで 1 バイトも届かない。**「Issue が close された」は取り込み済みを意味しない
- ⚠ ginseng-style を上げるときは `Gemfile` と CI の composite action の SHA を**同時に**書き換える（`docs/CLAUDE.md` の「固有の差分」）

### Ruby 本体

🔴 **毎回必ず回す。**Ruby を pin していないので Dependabot は何も言わない（#192）。

```sh
ruby .claude/skills/sync/scripts/ruby_versions.rb
```

CI の matrix の系列ごとに、上流の最新パッチ・EOL と、**OS が配る版**（FreeBSD は ports の `main` と当期の quarterly・Ubuntu は実機の系列 `resolute` の公開日）を並べる。

- ⚠ **ports に入っても pkg が届くのはビルドの後**（quarterly は数日遅れる）。実機の版は `ruby -v` で見る
- ⚠ **Ubuntu は版番号を上げずにパッチを当てる**（`3.3.8-2ubuntu3.1` のまま CVE が直ることがある）。だから公開日で見て、「上流より前」なら未取り込み、後なら changelog で CVE を確かめる
- ⚠⚠ **まず上流の修正がこの系列にバックポートされたかを見る。**「この系列に無い」と出たら、OS が取り込む元がそもそも無い（4.0 系だけの修正か、系列が EOL）。⚠ Ubuntu は EOL 後も自前でパッチを当てうるが、FreeBSD の ports は系列ごと消える（2026-07-18 の `ruby33` 消失）。EOL の予定日が近づいたら、CI の matrix と chubo2 の `ruby.system.version` の引き上げを利用側と話す
- 上流の修正がセキュリティなら、受け皿の Issue（#192 の形）を立てて、OS 側が取り込むまで開けておく。⚠ **リポジトリ側の作業は通常無い**（CI の matrix は浮動指定）

## 7. マイルストーンとバージョン

- `gh api 'repos/THE-POWERNEWS/writersbase-tools/milestones?state=open' --jq '.[]|"\(.title) open=\(.open_issues)"'`
- `/package/version`（`config/application.yaml`）・最新タグ（`git describe --tags`）・開いているマイルストーンのずれを見る。⚠ バンプは新しいマイルストーンに着手したとき、タグはリリース手順を通してから（どちらも委譲済み）

## 8. 報告

日本語で、次の順にまとめる。

1. **判断を仰ぐもの**（起票・docs の更新・マージの候補）を冒頭に。各項目に「すぐ／次のマイルストーン／見送り」の推奨を付ける
2. 前回から変わったこと
3. 変わっていないこと（確認した項目は「確認した」と書く。取得失敗は「未確認」）

## 9. 報告のあと

判断をもらってから行う。

- Issue の起票・コメント
- `docs/CLAUDE.md` の更新（⚠ **特にリリース済みバージョンの反映**）。ブランチを切って PR にする（`--base main`）
- `MEMORY.md` の更新（手元なので報告の前でもよい）
