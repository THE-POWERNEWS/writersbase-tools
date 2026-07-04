module WritersBase
  class MastodonMaintenanceTool < Tool
    include MastodonTootctl

    def exec(args = {})
      result = {success: [], failure: []}
      commands.each do |cmd|
        tootctl_args = cmd.split(/\s+/)
        logger.info(tool: underscore, command: cmd, message: '実行開始')
        tootctl_command(tootctl_args)
        result[:success].push(cmd)
      rescue => e
        logger.error(tool: underscore, command: cmd, error: e.message.strip)
        result[:failure].push(command: cmd, error: e.message.strip)
      end
      return result
    end

    def description
      return 'Mastodonのメンテナンスコマンドを実行します。'
    end
  end
end
