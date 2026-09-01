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
  puts Tool.create(name).body(ARGV)
rescue => e
  # ⚠ **ここが唯一の集約点。** ツールの例外はすべてここへ来るので、
  # Sentry へはここだけで送る（#37）。bundle 未充足の早期失敗は SDK が
  # まだ読めていないので対象外。
  capture_error(e, tool: ARGV.first)
  warn e.message
  exit 1
end
