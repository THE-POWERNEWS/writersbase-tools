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
  warn e.message
  exit 1
end
