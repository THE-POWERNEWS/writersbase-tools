#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.expand_path('..', __dir__), 'app/lib'))

require 'writers_base'
module WritersBase
  raise 'tool undefined' unless name = ARGV.first&.underscore
  puts Tool.create(name).body(ARGV)
rescue => e
  warn e.message
  exit 1
end
