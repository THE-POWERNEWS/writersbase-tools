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

    def self.test?
      return ENV['TEST'].present? rescue false
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

    def self.type
      # ⚠ `|| 'development'` ではキーが無いときに例外になる（#104）
      return config.lookup('/environment', 'development')
    end

    def self.development?
      return type == 'development'
    end

    def self.production?
      return type == 'production'
    end
  end
end
