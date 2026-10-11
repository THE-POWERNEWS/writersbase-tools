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
    # ⚠ 非 TTY の進捗バーは `Progress: |=====|` の 1 行になる（dev24 で実測）。情報が無いので落とす
    PROGRESS_PATTERN = /\AProgress: \|/
    # ⚠ **失敗時（`ERROR_HEAD` / `ERROR_TAIL`）より長く取る。**あちらは Sentry の 1,024 文字に
    # 合わせた値で、`statuses remove` だと肝心の「removed N out of M statuses」が省略に落ちた
    # （dev24 で実測）。こちらはログにしか出ないので、効くのは FreeBSD の syslogd の
    # 8,087 バイトだけ。全部が 3 バイト文字でも収まる長さにしてある
    OUTPUT_HEAD = 800
    OUTPUT_TAIL = 1200

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
    # FreeBSD の syslogd は切り詰める（#119）。失敗時の stderr と同じ縮め方（先頭と末尾）に寄せる。
    # ⚠ TTY の進捗バーは `\r` で上書きするので、改行と同じ区切りとして扱う。
    def output_summary(command)
      lines = command.stdout.to_s.scrub.gsub(ANSI_PATTERN, '').split(/[\r\n]+/).map(&:strip)
      text = lines.reject {|line| line.empty? || PROGRESS_PATTERN.match?(line)}.join("\n")
      return abbreviate(command.masked(text), head: OUTPUT_HEAD, tail: OUTPUT_TAIL)
    end
  end
end
