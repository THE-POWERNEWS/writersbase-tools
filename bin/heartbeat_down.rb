#!/usr/bin/env ruby
# periodic のスクリプトが `bin/wb` まで届かずに落ちたとき、Kuma へ `down` を送る（#174）。
#
# ⚠⚠ **bundler を通さない。**呼ばれるのは bundle が壊れているときなので、`require 'bundler'` も
# `writers_base` も読まない（stdlib だけで動く `HeartbeatFallback` だけを読む）。
# ⚠ 監視のための仕掛けなので、送れなくても呼び出し側の終了コードは変えさせない
# （スクリプト側が `|| true` で受ける）。理由は例外のクラス名だけ出す（本文に URL が載りうる）。
begin
  require_relative '../app/lib/writers_base/heartbeat_fallback'
  tool, message = ARGV
  raise ArgumentError, 'tool undefined' if tool.to_s.empty?
  WritersBase::HeartbeatFallback.new(tool).down(message)
rescue StandardError, ScriptError => e
  warn "ハートビート送信失敗 (#{e.class})"
  exit 1
end
