module WritersBase
  class MastodonFollowTool < Tool
    include MastodonTootctl

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
  end
end
