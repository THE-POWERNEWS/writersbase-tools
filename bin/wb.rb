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
  # ⚠ 成功したときだけ up を送る（#91）。失敗は下の集約点から down を送る
  # ⚠ 失敗ではないが要対応なもの（再起動待ちの放置など）は、ここで down を送る（#141）
  heartbeat = Heartbeat.new(name)
  if alert = tool.alert
    heartbeat.down(alert)
  else
    heartbeat.up(tool.status_message)
  end
rescue => e
  # ⚠ **ここが唯一の集約点。** ツールの例外はすべてここへ来るので、
  # Sentry へはここだけで送る（#37）。bundle 未充足の早期失敗は SDK が
  # まだ読めていないので対象外。
  # ⚠⚠ **ハートビートを先に送る。**Sentry より手前に置くのは、送信経路が
  # 詰まっている場合でも「失敗した」という事実だけは外へ出したいため（#91）。
  Heartbeat.new(ARGV.first.to_s).down(e.message)
  capture_error(e, tool: ARGV.first)
  warn e.message
  exit 1
end
