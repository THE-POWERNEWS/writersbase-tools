module WritersBase
  class Environment < Ginseng::Environment
    include Package

    def self.name
      return File.basename(dir)
    end

    def self.dir
      return WritersBase.dir
    end

    def self.rake?
      return ENV['RAKE'].present? && !test? rescue false
    end

    # 対応プラットフォームを `:freebsd` / `:debian` の 2 値に揃えて返す。
    # ⚠⚠ **未対応なら例外にする。**`case` の `else` 抜けは `nil` を返し、
    # 「再起動は不要」（`reboot_required`）・「group を変えずに chown 成功」（`root_group`）・
    # 「0 件インストールして成功」（`Installer`・#72）のように**黙って倒れる**（#122）。
    # ⚠ 判定はここに寄せ、呼び出し側で `case Environment.platform` を書き直さないこと。
    def self.platform_family(platform = self.platform)
      case platform
      when :free_bsd, :freebsd
        return :freebsd
      when :debian
        return :debian
      end
      raise "未対応のプラットフォームです (#{platform.inspect})"
    end

    # ginseng-upstream: no — 上流の type は RACK_ENV / RAILS_ENV を優先して Symbol を返す（Rack アプリ向け）。
    # これは cron などから動く道具なので config の /environment だけを見て、Sentry の environment へ文字列で渡す。
    # ⚠ `development?` / `production?` は上流のもの（`type.to_s` で比べるので、文字列のままでよい）
    def self.type
      # ⚠ `|| 'development'` ではキーが無いときに例外になる（#104）
      return config.lookup('/environment', 'development')
    end
  end
end
