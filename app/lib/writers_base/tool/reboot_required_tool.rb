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

    def freebsd_reboot_required?
      running = CommandLine.new(['uname', '-r'])
      running.exec
      installed = CommandLine.new(['freebsd-version', '-k'])
      installed.exec
      return running.stdout.strip != installed.stdout.strip
    end
  end
end
