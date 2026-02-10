module WritersBase
  class MastodonFollowTool < Tool
    def exec(args = {})
      result = {success: [], failure: []}
      logger.info(tool: underscore, account:, message: 'フォロー実行開始')
      tootctl_command(['account', 'follow', account])
      result[:success].push(account)
      return result
    rescue => e
      logger.error(tool: underscore, account:, error: e.message.strip)
      result[:failure].push(account:, error: e.message.strip)
      return result
    end

    def description
      return '全ユーザーに指定アカウントを強制フォローさせます。'
    end

    private

    def tootctl_command(args)
      command = CommandLine.new(
        ['bundle', 'exec', 'bin/tootctl', *args],
      )
      command.user = mastodon_user
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
