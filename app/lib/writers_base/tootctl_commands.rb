module WritersBase
  # `/<ツール名>/commands` に並べた tootctl のサブコマンドを順に実行する（#124）。
  #
  # ⚠ `MastodonMaintenanceTool` と `MastodonMediaCleanupTool` は `description` 以外が
  # 同一だった。⚠⚠ **1 クラスにまとめるとツール名が変わる**（node yaml と periodic
  # スクリプトが名前で呼んでいる）ので、クラスは残して `exec` だけをここへ寄せる。
  module TootctlCommands
    include MastodonTootctl

    # ⚠ 非 TTY では色は付かないはずだが、手で回したときの出力も同じ経路を通る
    ANSI_PATTERN = %r{\e\[[0-9;?]*[ -/]*[@-~]}

    def exec(args = {})
      result = {success: [], failure: []}
      commands.each do |cmd|
        tootctl_args = cmd.split(/\s+/)
        logger.info(tool: underscore, command: cmd, message: '実行開始')
        command = tootctl_command(tootctl_args)
        output = output_summary(command)
        logger.info(tool: underscore, command: cmd, message: '実行完了', output:)
        result[:success].push(cmd)
      rescue => e
        logger.error(tool: underscore, command: cmd, error: e.message.strip)
        result[:failure].push(command: cmd, error: e.message.strip)
      end
      return result
    end

    private

    # tootctl の標準出力をログへ残す（#175）。
    #
    # ⚠⚠ **`statuses remove --keep-tags` は、綴りを間違えたタグを黙って無視する**
    # （pooza/mastodon#977）。気づく手がかりは `Keeping statuses tagged with:` の行だけで、
    # 捨てていると periodic 経由では確かめようがない（pooza/chubo2#261）。
    # ⚠ **丸ごとは載せない。**進捗バーで長くなりうるし、長い行は journald が捨て、
    # FreeBSD の syslogd は切り詰める（#119）。失敗時の stderr と同じ縮め方に寄せる。
    # ⚠ 進捗バーは `\r` で上書きするので、改行と同じ区切りとして扱う。
    def output_summary(command)
      lines = command.stdout.to_s.scrub.gsub(ANSI_PATTERN, '').split(/[\r\n]+/)
      return abbreviate(command.masked(lines.map(&:strip).reject(&:empty?).join("\n")))
    end
  end
end
