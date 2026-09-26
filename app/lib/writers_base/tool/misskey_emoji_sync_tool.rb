module WritersBase
  # 姉妹Misskeyサーバーからカスタム絵文字を引き取り、増えたぶんをお知らせボットへ
  # 告知する日次タスク（pooza/mastodon#950）。
  #
  # ⚠⚠ webhookはモロヘイヤのWebhook URLで、**URL自体が資格情報**（インスタンスURI＋
  # アカウントのトークン＋saltのSHA256）。
  #
  # 🔴 **以前は `tootctl emoji sync --webhook <url>` として引数に載せていたので、
  # 同居する非 root ユーザから `ps` で読めた**（#127・2026-09-20 に実測）。
  # `CommandLine#secrets`（#65）が伏せるのはログと例外で、**プロセスリストは伏せない。**
  # tootctl の `--webhook` は環境変数や stdin から受ける口を持たない。
  #
  # ⚠ いまは tootctl には `--announce`（下書きを標準出力へ出すだけ）を渡し、
  # **告知の投稿はこちら（Ruby）から送る**（#121 の `Heartbeat` と同じ形）。
  # URL はどのプロセスの引数にも載らない。ログに出る経路（`Ginseng::HTTP#log` の
  # `url:`）は `/logger/mask_url_paths` の `/webhook/` で伏せる。⚠ 伏せられない URL
  # （接頭辞が当たらないもの）は、tootctl を走らせる前に設定エラーで止める。
  # ⚠ 下書きの文面・文字数上限での分割は tootctl 側の仕事のまま。こちらは切り出して送るだけ。
  # ⚠ 結果（`exec` の戻り値）には URL を載せない（`announced` の真偽だけ）。
  class MisskeyEmojiSyncTool < Tool
    include MastodonTootctl

    # ⚠ 出力は初回同期だと数百件のショートコードを含む。日次ログには要点だけ残す
    REPORTED_PREFIXES = /\A(Copied|Posted|Failed|Nothing to announce)/

    # tootctl の `say_drafts` が出す形（`--- announcement[ i/n] ---` 〜 `--- end ---`）
    DRAFT_PATTERN = %r{^--- (announcement(?: \d+/\d+)?) ---\n(.*?)\n--- end ---$}m

    # tootctl の `announce` は、下書きが無ければこの 1 行を出す。⚠ 下書きとこの行の
    # **どちらかが必ず出る**ので、どちらも無ければ書式がずれたと読む（#144）
    NOTHING_PATTERN = /^Nothing to announce\.$/

    def exec(args = {})
      origin = setting(:origin)
      raise Ginseng::ConfigError, "'/#{underscore}/origin' not found" if origin.blank?
      raise Ginseng::ConfigError, "'/#{underscore}/webhook' is not masked" unless webhook_masked?
      logger.info(tool: underscore, origin:, message: '実行開始')
      command = tootctl_command(tootctl_args(origin))
      result = {origin:, announced: 0, report: report(command.stdout), failure: []}
      announce(command.stdout, result) if webhook.present?
      return result
    end

    def description
      return '姉妹Misskeyサーバーからカスタム絵文字を取り込み、増えたぶんを告知します。'
    end

    private

    # ⚠ Ginseng::Configは未設定のキーで例外を投げる。originは無ければ落としたいが、
    # webhookは「告知しない」という正当な設定なので、ここで分けずにnilへ倒して
    # 呼び出し側で判断する
    # ⚠ 既定へ倒す口は Config#lookup に寄せた（#104）
    def setting(key)
      return config.lookup("/#{underscore}/#{key}")
    end

    def webhook
      return setting(:webhook)
    end

    # ⚠⚠ ログの `url:` を伏せるのは `/logger/mask_url_paths` で、**パスの接頭辞を
    # 知っているものしか伏せない。**Slack の `/services/...` のような URL は素通りする。
    # 道具側で同等品を書かず（マスクの正本は `Ginseng::Masking`）、伏せられない URL なら
    # **tootctl を走らせる前に**止める。同期のあとで止めると、告知が二度と出ない
    # ⚠⚠ **URL 全体ではなくパスで比べる**（Codex P2）。`?access_token=` のような
    # クエリだけが伏せられても、資格情報の載ったパスは素のまま残る
    def webhook_masked?
      return true if webhook.blank?
      return Ginseng::URI.parse(logger.mask_url(webhook)).path != Ginseng::URI.parse(webhook).path
    end

    # ⚠⚠ `--webhook` を渡さないこと（#127）。渡すと URL がプロセスの引数に載る
    def tootctl_args(origin)
      args = ['emoji', 'sync', origin, '--no-dry-run']
      args.push('--announce') if webhook.present?
      return args
    end

    def drafts(stdout)
      return stdout.to_s.scan(DRAFT_PATTERN).map {|label, text| {label:, text:}}
    end

    # ⚠⚠ 下書きを 1 件も拾えず、`Nothing to announce.` も無いなら、tootctl の書式が
    # ずれて**告知を取りこぼした**と読む（#144）。同期は済んでいて次回は差分ゼロなので、
    # 黙って成功させると告知は二度と出ない。`failure` に積んで Sentry / Kuma へ届ける
    def announce(stdout, result)
      drafts = drafts(stdout)
      return post_drafts(drafts, result) if drafts.present?
      return if stdout.to_s.match?(NOTHING_PATTERN)
      error = '告知の下書きを tootctl の出力から拾えませんでした'
      logger.error(tool: underscore, error:)
      result[:failure].push(error:)
    end

    # ⚠ 投稿の失敗で同期そのものは止めない（書き込みは済んでいる）。ただし tootctl の
    # `--webhook` は失敗しても exit 0 で**黙って消えていた**ので、こちらでは
    # `failure` に積んで Sentry / Kuma へ届ける。⚠ 次回は差分ゼロで告知が出ないので、
    # **失敗した告知は手で出す**しかない。
    def post_drafts(drafts, result)
      drafts.each do |draft|
        post_draft(draft[:text])
        result[:announced] += 1
        result[:report].push("Posted #{draft[:label]}.")
      rescue => e
        error = post_error(e)
        logger.error(tool: underscore, announcement: draft[:label], error:)
        result[:report].push("Failed to post #{draft[:label]}: #{error}")
        result[:failure].push(announcement: draft[:label], error:)
      end
    end

    def post_draft(text)
      return if test?
      return http.post(webhook, body: {text:})
    end

    def http
      http = HTTP.new
      # ⚠⚠ **再送しない。**相手が受け取ったあとで応答だけ落ちると、同じ告知が 2 回出る
      http.retry_limit = 1
      return http
    end

    # ⚠ 例外の文面を出さない。接続まわりの例外は URL（の一部）を含みうるので、
    # tootctl 側（`post_drafts`）と同じく HTTP のコードか例外クラスだけにする
    def post_error(error)
      code = error.response&.code if error.respond_to?(:response)
      return "HTTP #{code}" if code
      return error.class.to_s
    end

    def report(stdout)
      return stdout.to_s.each_line.map(&:strip).grep(REPORTED_PREFIXES)
    end
  end
end
