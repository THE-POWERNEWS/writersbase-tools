#!/usr/bin/env ruby
require 'bundler'
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

begin
  require 'writers_base'
rescue Bundler::BundlerError => e
  root = File.expand_path('..', __dir__)
  warn 'writersbase-toolsのbundleが未充足です。'
  warn "`cd #{root} && bundle install` を実行してください。"
  warn "詳細: #{e.message.lines.first&.strip}"
  exit 1
end
module WritersBase
  raise 'tool undefined' unless name = ARGV.first&.underscore
  tool = Tool.create(name)
  puts tool.body(ARGV)
  # ⚠⚠ **道具は失敗を自分で握って `result[:failure]` に積み、正常に return する。**
  # そのままだと exit 0 で、cron / periodic からは成功に見える。まとめて 1 件の
  # 例外にして、下の集約点（Sentry と非ゼロ終了）へ載せる（#64）。
  raise tool.failure_error if tool.failed?
rescue => e
  # ⚠ **ここが唯一の集約点。** ツールの例外はすべてここへ来るので、
  # Sentry へはここだけで送る（#37）。bundle 未充足の早期失敗は SDK が
  # まだ読めていないので対象外。
  capture_error(e, tool: ARGV.first)
  warn e.message
  exit 1
end
