module WritersBase
  class MastodonMaintenanceTool < Tool
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

    private

    def tootctl_command(args)
      command = CommandLine.new(
        ['sudo', '-u', mastodon_user, 'bundle', 'exec', 'bin/tootctl', *args],
      )
      command.env = {'RAILS_ENV' => mastodon_rails_env}
      command.dir = mastodon_dir
      unless test?
        command.exec
        raise command.stderr if command.status.nonzero?
      end
      return command
    end

    def mastodon_user = config['/mastodon/user']
    def mastodon_rails_env = config['/mastodon/rails_env']
    def mastodon_dir = config['/mastodon/dir']
  end
end
