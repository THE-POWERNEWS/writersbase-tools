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
      return File.exist?('/var/run/reboot-required')
    end
  end
end
