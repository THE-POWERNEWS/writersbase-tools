module WritersBase
  class MastodonMaintenanceTool < Tool
    include TootctlCommands

    def description
      return 'Mastodonのメンテナンスコマンドを実行します。'
    end
  end
end
