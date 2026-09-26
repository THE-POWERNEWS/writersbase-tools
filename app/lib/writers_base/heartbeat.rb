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
  # ⚠⚠ **push URL はそれ自体が資格情報。**トークンが**パスに入る**。
  #
  # 🔴 **以前は curl の引数として渡していたので、同居する非 root ユーザから `ps` で
  # 読めた**（#121）。⚠ `CommandLine#secrets`（#65）が伏せるのは**ログと例外**で、
  # **プロセスリストは伏せない。**実測（2026-09-20）では vulcan の `/proc` に
  # `hidepid` が無く（非 root の `misskey` から root の `cmdline` が読めた）、
  # shallu は `security.bsd.see_other_uids: 1` だった。
  #
  # ⚠ いまは Ruby 側から送るので、**URL はどのプロセスの引数にも載らない。**
  # ログに出る経路（`Ginseng::HTTP#log` の `url:`）は `/logger/mask_url_paths` の
  # `/api/push/` で伏せる。⚠⚠ **道具側で同等品を書かない**（マスクの正本は
  # `Ginseng::Masking`）。
  class Heartbeat
    include Package

    # ⚠ Kuma 側の msg は一覧に出る。長い stderr を丸ごと送らない
    MESSAGE_LIMIT = 200

    def initialize(tool)
      @tool = tool.to_s.underscore
      @logger = Logger.new
      @config = Config.instance
    end

    def up(message = 'OK')
      return push('up', message)
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
      query = query_params(status, message)
      return query if Environment.test?
      return http.get(url, query:)
    rescue => e
      # ⚠ 例外の本文には URL がそのまま載る（HTTParty / GatewayError）。伏せてから出す
      @logger.warn(tool: @tool, status:, message: 'ハートビート送信失敗', error: masked(e.message))
      return nil
    end

    def query_params(status, message)
      return {status:, msg: summarize(message)}
    end

    def http
      http = http_class.new
      # ⚠⚠ **再送しない。**`down` は bin/wb の集約点から、Sentry へ送るより**手前**で
      # 呼ばれる（#91）。既定（3 回・各 1 秒）のままだと、通知が詰まっているときに
      # **失敗の報告そのものが遅れる**。1 回試して駄目なら諦める。
      http.retry_limit = 1
      http.timeout = timeout
      return http
    end

    # ⚠ トークンは URL の**パス**に入るので、本文へ紛れ込んだら伏せる。
    # ⚠⚠ **空のトークンで gsub しないこと**（1 文字ごとに印が挟まる）。
    def masked(text)
      text = WritersBase.scrub_sentry_text(text.to_s).strip
      return text if token.blank?
      return text.gsub(token.to_s, Ginseng::Masking::FILTERED)
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
