# writersbase-tools

VPS上で実行するサーバー管理ユーティリティ集。FreeBSD / Ubuntu Server対応。

⚠ **位置づけ・規約・進め方・リリース手順・進捗の同期手順の正本は [docs/](docs/README.md)。** 以下にはコードを触るときの構造だけを置く。

@docs/CLAUDE.md

## プロジェクト構造

- `app/lib/writers_base.rb` - エントリポイント。Zeitwerkでオートロード、`Bundler.require`で自動require
- `app/lib/writers_base/tool.rb` - 全ツールの基底クラス。`method_missing`で`config["/#{underscore}/key"]`を自動取得
- `app/lib/writers_base/tool/*.rb` - 個別ツール。`Tool`を継承し`exec`と`description`を実装
- `app/lib/writers_base/installer.rb` - cronスクリプトのインストーラ
- `bin/wb.rb` - ツール実行エントリポイント (`bin/wb <tool_name>`)
- `config/application.yaml` - デフォルト設定。ツール名をキーにして各設定を格納
- `config/local.yaml` - 環境固有の設定（Git管理対象外）。`application.yaml`の値を上書き
- `config/autoload.yaml` - Zeitwerk inflection設定

## ツール追加パターン

1. `app/lib/writers_base/tool/<name>_tool.rb` にクラスを追加（`Tool`を継承）
2. `exec(args = {})` と `description` を実装
3. `config/application.yaml` にデフォルト設定を追加
4. `README.md` のツール一覧と設定セクションを更新

## 開発ツール

- RuboCop: `bundle exec rubocop` (自動修正: `bundle exec rubocop -a`)
- テスト: `bin/wb help` で動作確認可能
- GitHub CLI: `gh`

## Mastodon関連ツールの共通パターン

- `config/application.yaml`の`mastodon`セクション（user, rails_env, dir）を共通設定として参照
- tootctlの実行は`sudo -u`＋`CommandLine`で、`RAILS_ENV`環境変数とディレクトリを設定
- 現在FreeBSD専用（Ubuntu対応は不要）

## 注意点

- 外部gemのrequireは不要（`Bundler.require`で自動ロード）
- PostgreSQL 15+が必要（`pg_backup_start`/`pg_backup_stop`使用のため）

## ドキュメント

- [docs/CLAUDE.md](docs/CLAUDE.md) — 規約の正本・ブランチ・リリース運用・進捗の同期手順・情報の記載先
- [docs/positioning.md](docs/positioning.md) — ⚠ **名前に反して writersBASE 向けではない**／実際の利用者は chubo2 のフリート
- [docs/deployment.md](docs/deployment.md) — 2 経路の cookbook・設定の置き場・⚠ 罠と既知の課題
