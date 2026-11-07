# ginseng-* のピンのずれを出す（Dependabot から外してあるので、ここでしか拾えない・#139）。
# tag 固定（ginseng-core）はタグ名、SHA 固定（ginseng-style）はその SHA が最新タグを指すかで比べる。
# 使い方: リポジトリのルートから ruby .claude/skills/sync/scripts/ginseng_pin_drift.rb
# ⚠ 作業ツリーではなく origin/main の Gemfile を読む（古いブランチに乗っていても誤読しない）
require 'English'

gemfile = `git show origin/main:Gemfile`
abort '🔴 取得失敗: origin/main の Gemfile を読めない' unless $CHILD_STATUS.success?
found = false
pattern = /gem .(ginseng-[\w-]+).,\s+github: \S+,\s+(tag|ref): .(\w[\w.]*)./
gemfile.scan(pattern) do |name, kind, pin|
  found = true
  tags = `git ls-remote --tags --sort=-v:refname https://github.com/pooza/#{name}.git "v*"`
  latest = tags[%r{refs/tags/(v[\d.]+)$}, 1]
  if latest.nil?
    puts "#{name}\t🔴 取得失敗（タグを読めない）"
    next
  end
  sha_ok = tags.match?(%r{^#{pin}\trefs/tags/#{Regexp.escape(latest)}(\^\{\})?$})
  ok = kind == 'tag' ? pin == latest : sha_ok
  puts "#{name}\t#{ok ? "最新 #{latest}" : "ずれ #{pin[0, 12]} -> #{latest}"}"
end
abort '🔴 Gemfile に ginseng-* の行が見つからない（正規表現が古い）' unless found
