module WritersBase
  # `/<ツール名>/commands` に並べた tootctl のサブコマンドを順に実行する（#124）。
  #
  # ⚠ `MastodonMaintenanceTool` と `MastodonMediaCleanupTool` は `description` 以外が
  # 同一だった。⚠⚠ **1 クラスにまとめるとツール名が変わる**（node yaml と periodic
  # スクリプトが名前で呼んでいる）ので、クラスは残して `exec` だけをここへ寄せる。
  module TootctlCommands
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
  end
end
