# Ruby 本体の更新を拾う（Ruby を pin していないので Dependabot は何も言わない・#192）。
# CI の matrix の系列ごとに、上流の最新パッチ・EOL・FreeBSD ports（main と当期の quarterly）・
# Ubuntu resolute の公開日を並べる。
# 使い方: リポジトリのルートから ruby .claude/skills/sync/scripts/ruby_versions.rb
require 'date'
require 'json'
require 'open-uri'
require 'yaml'

get = ->(u) {URI.parse(u).open(&:read)}
www = 'https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data'
rel = YAML.safe_load(get.call("#{www}/releases.yml"), permitted_classes: [Date])
br = YAML.safe_load(get.call("#{www}/branches.yml"), permitted_classes: [Date])
newest = rel.select {|r| r['version'].to_s.match?(/\A\d+\.\d+\.\d+\z/)}.max_by {|r| r['date']}
quarter = "#{Date.today.year}Q#{(Date.today.month + 2) / 3}"
ports = ['main', quarter].to_h do |b|
  mk = get.call("https://raw.githubusercontent.com/freebsd/freebsd-ports/#{b}/Mk/Uses/ruby.mk")
  [b, mk.scan(/^RUBY_DISTVERSION=\s+(\S+)/).flatten]
end
series = File.read('.github/workflows/test.yml')[/ruby: \[(.*)\]/, 1].scan(/[\d.]+/)
series.each do |s|
  up = rel.select {|r| r['version'].to_s.match?(/\A#{Regexp.escape(s)}\.\d+\z/)}
    .max_by {|r| Gem::Version.new(r['version'].to_s)}
  b = br.find {|x| x['name'].to_s == s}
  line = "ruby #{s}\t#{b['status']}（EOL #{b['eol_date'] || b['expected_eol_date'] || '未定'}）"
  line << "\t上流 #{up['version']}（#{up['date']}）"
  line << "\t⚠ #{newest['version']}（#{newest['date']}）がこの系列に無い" if up['date'] < newest['date']
  ports.each do |branch, vs|
    v = vs.find {|x| x.start_with?("#{s}.")} or next
    line << "\tports/#{branch} #{v}#{' ずれ' if v != up['version'].to_s}"
  end
  lp = 'https://api.launchpad.net/1.0/ubuntu'
  q = ["ws.op=getPublishedSources&source_name=ruby#{s}&exact_match=true",
    "status=Published&distro_series=#{lp}/resolute"].join('&')
  es = JSON.parse(get.call("#{lp}/+archive/primary?#{q}"))['entries']
  if (e = es.max_by {|x| x['date_published']})
    pub = Date.parse(e['date_published'])
    line << "\tresolute #{e['source_package_version']}（#{pub}#{' 上流より前' if pub < up['date']}）"
  end
  puts line
end
