module WritersBase
  # 姉妹Misskeyサーバーからカスタム絵文字を引き取り、増えたぶんをお知らせボットへ
  # 告知する日次タスク（pooza/mastodon#950）。
  #
  # ⚠ webhookはモロヘイヤのWebhook URLで、**URL自体が資格情報**（インスタンスURI＋
  # アカウントのトークン＋saltのSHA256）。tootctl側が失敗の文面からも伏字化して扱うので、
  # ここでも組み立てるだけにして、ログにも結果にも載せない。
  class MisskeyEmojiSyncTool < Tool
    include MastodonTootctl

    # ⚠ 出力は初回同期だと数百件のショートコードを含む。日次ログには要点だけ残す
    REPORTED_PREFIXES = /\A(Copied|Posted|Failed|Nothing to announce)/

    def exec(args = {})
      origin = setting(:origin)
      raise Ginseng::ConfigError, "'/#{underscore}/origin' not found" if origin.blank?
      logger.info(tool: underscore, origin:, message: '実行開始')
      command = tootctl_command(tootctl_args(origin))
      return {origin:, announced: setting(:webhook).present?, report: report(command.stdout)}
    end

    def description
      return '姉妹Misskeyサーバーからカスタム絵文字を取り込み、増えたぶんを告知します。'
    end

    private

    # ⚠ Ginseng::Configは未設定のキーで例外を投げる。originは無ければ落としたいが、
    # webhookは「告知しない」という正当な設定なので、ここで分けずにnilへ倒して
    # 呼び出し側で判断する
    def setting(key)
      return config["/#{underscore}/#{key}"]
    rescue Ginseng::ConfigError
      return nil
    end

    def tootctl_args(origin)
      args = ['emoji', 'sync', origin, '--no-dry-run']
      webhook = setting(:webhook)
      args.push('--webhook', webhook) if webhook.present?
      return args
    end

    def report(stdout)
      return stdout.to_s.each_line.map(&:strip).grep(REPORTED_PREFIXES)
    end
  end
end
