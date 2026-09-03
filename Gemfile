source 'https://rubygems.org'
gem 'concurrent-ruby'
gem 'fileutils'
gem 'ginseng-core', github: 'pooza/ginseng-core', require: 'ginseng'
gem 'mysql2'
gem 'optparse'
gem 'parallel'
gem 'pg'
gem 'sentry-ruby'

group :development do
  # ⚠ 参照は SHA で固定する。タグは付け替えられるため（pooza/ginseng-style#75）。
  # 末尾のコメントは人が読むためのもので、検査には使わない。
  gem 'ginseng-style', github: 'pooza/ginseng-style',
    ref: 'ed862dcf9550d704ee670f65a30a333a694b883a', require: false # v1.1.12
  gem 'ricecream'
  gem 'test-unit'
end
