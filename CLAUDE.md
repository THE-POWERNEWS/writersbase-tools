# writersbase-tools

VPS上で実行するサーバー管理ユーティリティ集。FreeBSD / Ubuntu Server対応。

## プロジェクト構造

- `app/lib/writers_base.rb` - エントリポイント。Zeitwerkでオートロード、`Bundler.require`で自動require
- `app/lib/writers_base/tool.rb` - 全ツールの基底クラス。`method_missing`で`config["/#{underscore}/key"]`を自動取得
- `app/lib/writers_base/tool/*.rb` - 個別ツール。`Tool`を継承し`exec`と`description`を実装
- `app/lib/writers_base/installer.rb` - cronスクリプトのインストーラ
- `bin/wb.rb` - ツール実行エントリポイント (`bin/wb <tool_name>`)
- `config/application.yaml` - 全設定。ツール名をキーにして各設定を格納
- `config/autoload.yaml` - Zeitwerk inflection設定

## ツール追加パターン

1. `app/lib/writers_base/tool/<name>_tool.rb` にクラスを追加（`Tool`を継承）
2. `exec(args = {})` と `description` を実装
3. `config/application.yaml` に設定を追加
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
