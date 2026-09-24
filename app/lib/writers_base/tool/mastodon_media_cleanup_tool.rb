module WritersBase
  class MastodonMediaCleanupTool < Tool
    include TootctlCommands

    def description
      return 'Mastodonの古いメディアファイルを削除します。'
    end
  end
end
