module WritersBase
  class RebootRequiredTool < Tool
    def exec(args = {})
      return '再起動が必要' if reboot_required?
      return ''
    end

    def description
      return 'システムに再起動が必要かを判定します。'
    end

    private

    def reboot_required?
      case Environment.platform
      when :free_bsd, :freebsd
        return freebsd_reboot_required?
      when :debian
        return File.exist?('/var/run/reboot-required')
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
