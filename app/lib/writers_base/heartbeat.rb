module WritersBase
  # 実行結果を Uptime Kuma の push モニタへ送る（#91）。
  #
  # 🔴 **push モニタは「ハートビートが途切れたら DOWN」という向き。**だから失敗時だけ
  # 送るのでは足りず、**成功時も送る**。⚠ これは欠点ではなく利点で、**そもそも走らなかった**
  # （宣言漏れ・ノード停止・cron の設置漏れ）も DOWN になる —— Sentry には無い利点。
  # pooza/chubo2#244（monit → Kuma）と同じ判断で、通知の宛先もそこへ揃える。
  #
  # ⚠⚠ **監視のための仕掛けで本業を落とさない。**送信に失敗しても握りつぶして警告だけ出す
  # （cron から走る道具なので、バックアップが通知の都合で落ちるのは本末転倒）。
  # 届かないこと自体は Kuma 側でハートビート切れとして見える。
  #
  # ⚠⚠ **push URL はそれ自体が資格情報。**トークンが**パスに入る**ため、`Ginseng::HTTP` の
  # `log(url:)` では伏せられない（`mask_url` が見るのは userinfo とクエリ）。そこで
  # `CommandLine#secrets` に載せた curl で送る（#65 と同じ経路）。
  class Heartbeat
    include Package

    # ⚠ Kuma 側の msg は一覧に出る。長い stderr を丸ごと送らない
    MESSAGE_LIMIT = 200

    def initialize(tool)
      @tool = tool.to_s.underscore
      @logger = Logger.new
      @config = Config.instance
    end

    def up
      return push('up', 'OK')
    end

    def down(message)
      return push('down', message)
    end

    # ⚠ トークンを書いたツールだけ送る。書いていないノード・ツールでは何もしない
    def disable?
      return token.blank?
    end

    private

    def push(status, message)
      return nil if disable?
      command = CommandLine.new(args(status, message))
      command.secrets = [token, url]
      return command if Environment.test?
      command.exec
      return command if command.status.zero?
      # ⚠ stderr にも URL が載りうるので、伏せてから出す
      @logger.warn(tool: @tool, status:, message: 'ハートビート送信失敗',
        error: command.masked(command.stderr.strip))
      return command
    rescue => e
      @logger.warn(tool: @tool, message: 'ハートビート送信失敗', error: e.message.strip)
      return nil
    end

    def args(status, message)
      return [
        'curl', '-fsS', '--max-time', timeout.to_s, '--get',
        '--data-urlencode', "status=#{status}",
        '--data-urlencode', "msg=#{summarize(message)}",
        url
      ]
    end

    # ⚠ 失敗の本文には資格情報が載りうる（コマンドラインの環境変数・URL の userinfo）。
    # Sentry へ送る前と同じ網を通してから外へ出す（#65 / #37）。
    def summarize(message)
      return WritersBase.scrub_sentry_text(message.to_s).strip.gsub(/\s+/, ' ')[0, MESSAGE_LIMIT]
    end

    def url
      return File.join(base, token.to_s)
    end

    def base
      return @config.lookup('/heartbeat/base', 'https://uptime.b-shock.org/api/push')
    end

    def timeout
      return @config.lookup('/heartbeat/timeout', 20)
    end

    def token
      return @config.lookup("/heartbeat/tokens/#{@tool}")
    end
  end
end
