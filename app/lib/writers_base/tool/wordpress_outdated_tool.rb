module WritersBase
  # 導入済みの WordPress が、同じブランチ（major.minor）の最新版より古ければ知らせる（#138）。
  #
  # ⚠⚠ **自動更新の怖さは「上がらなかったことが静かに放置される」側にある。**
  # 2026-09-23 の CVE-2026-87902 では自動更新で無事だったが、当たったかどうかは
  # 手で `version.php` を見るまで誰も知らなかった。1 台だけ失敗していても同じく気づけない。
  #
  # ⚠ 検出だけを扱う。更新そのものは WordPress の自動更新に任せる。
  # ⚠ 古ければ文字列を返し、heartbeat を down にする（`reboot_required` と同じ形・#141）。
  # 失敗ではないので Sentry へは送らない。⚠ リリース直後は、自動更新が当たるまでの
  # 数時間だけ古く見えうる（次の回で up へ戻る）。
  class WordpressOutdatedTool < Tool
    VERSION_PATTERN = /^\$wp_version\s*=\s*'([^']+)'/

    def exec(args = {})
      # ⚠ WordPress の無いノード（wiki / vpn）では何もせず黙って終わる
      return '' if dirs.empty?
      @outdated = dirs.filter_map do |dir|
        installed = installed_version(dir)
        latest = latest_in_branch(latest_versions(installed), installed)
        next if installed >= latest
        "WordPress が古い（#{dir}: 導入 #{installed} / 最新 #{latest}）"
      end
      return @outdated.join("\n")
    end

    def description
      return '導入済みの WordPress が、同じブランチの最新版より古ければ知らせます。'
    end

    def alert
      return nil if @outdated.blank?
      return @outdated.join(' / ')
    end

    private

    def dirs
      return config.lookup("/#{underscore}/dirs", [])
    end

    # ⚠⚠ 読めなければ黙って「最新」へ倒さない（#63 / #122 と同じ型）。
    # 設定したディレクトリに WordPress が無いのは設定の誤りなので、例外にして表に出す。
    def installed_version(dir)
      path = File.join(dir, 'wp-includes/version.php')
      raise "#{path} がありません" unless File.exist?(path)
      version = File.read(path)[VERSION_PATTERN, 1]
      raise "#{path} から $wp_version を読めません" unless version
      return Gem::Version.new(version)
    end

    # ⚠ 修正版の番号を手で持つと、今度はその表が腐る。更新 API から引く。
    # ⚠⚠ API が落ちたときは例外にする（「引けなかった」こと自体を出す）。
    # ⚠ **導入版を `version` で渡す**（Codex P1）。API は「渡した版から見た更新候補」を返し、
    # 中身は渡した版で変わる（7.1.1 なら 7.1 系だけ）。素で引くと全ブランチが返るが、
    # それは約束された形ではない
    def latest_versions(installed)
      @latest_versions ||= {}
      @latest_versions[installed] ||= fetch_latest_versions(installed)
      return @latest_versions[installed]
    end

    def fetch_latest_versions(installed)
      response = http.get(api, query: {version: installed.to_s})
      return JSON.parse(response.body)['offers'].to_a.filter_map do |offer|
        Gem::Version.new(offer['current']) if offer['current'].present?
      end
    end

    # ⚠ 同じブランチの提供が API に無ければ、判定できないので例外にする
    # （ブランチが提供を打ち切られたなら、それ自体が要対応）。
    def latest_in_branch(offers, installed)
      branch = installed.segments.first(2)
      latest = offers.select {|v| v.segments.first(2) == branch}.max
      raise "WordPress #{branch.join('.')} の最新版を API から引けません" unless latest
      return latest
    end

    def http
      http = HTTP.new
      http.retry_limit = 1
      return http
    end
  end
end
