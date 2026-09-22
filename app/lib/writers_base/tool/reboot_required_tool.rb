module WritersBase
  class RebootRequiredTool < Tool
    DEBIAN_FLAG = '/var/run/reboot-required'.freeze

    def exec(args = {})
      return '再起動が必要' if reboot_required?
      return ''
    end

    def description
      return 'システムに再起動が必要かを判定します。'
    end

    private

    # ⚠⚠ 未対応のプラットフォームで `nil`（＝「再起動は不要」）を返さない（#122）。
    # #63 で塞いだ「uname が落ちると常に不要へ倒れる」と同じ型。
    def reboot_required?
      case platform_family
      when :freebsd
        return freebsd_reboot_required?
      when :debian
        return File.exist?(DEBIAN_FLAG)
      end
    end

    # ⚠ uname / freebsd-version が失敗すると空文字どうしの比較になり、
    # 「常に再起動不要」へ倒れていた。落ちたら黙らず例外にする（#63）。
    def freebsd_reboot_required?
      running = execute(['uname', '-r']).stdout.to_s.strip
      installed = execute(['freebsd-version', '-k']).stdout.to_s.strip
      return running != installed
    end
  end
end
