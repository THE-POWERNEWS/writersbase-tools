source 'https://rubygems.org'
gem 'concurrent-ruby'
gem 'fileutils'
gem 'ginseng-core', github: 'pooza/ginseng-core', tag: 'v2.2.0', require: 'ginseng'
gem 'mysql2'
gem 'optparse'
gem 'parallel'
gem 'pg'
gem 'sentry-ruby'

group :development do
  # ⚠ 参照は SHA で固定する。タグは付け替えられるため（pooza/ginseng-style#75）。
  # 末尾のコメントは人が読むためのもので、検査には使わない。
  gem 'ginseng-style', github: 'pooza/ginseng-style',
    ref: '2818c5618476302e4a10454f1b621502a053f492', require: false # v1.1.14
  gem 'ricecream'
  gem 'test-unit'
end
