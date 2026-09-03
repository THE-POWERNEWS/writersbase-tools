module WritersBase
  class CommandLine < Ginseng::CommandLine
    include Package

    # ⚠ Ginseng::Masking と同じ印。ログ・例外・Sentry で表記を揃える。
    FILTERED = '[FILTERED]'.freeze

    # ⚠⚠ **引数そのものが資格情報になることがある**（モロヘイヤの webhook URL は
    # インスタンス URI ＋ トークン ＋ salt の SHA256）。`Ginseng::CommandLine#log_exec` は
    # 実行のたびに `command:` として引数を丸ごとログへ出すが、
    # `WritersBase::Logger` のマスクは**キー名**でしか判定せず、
    # `Ginseng::Logger#mask_url` は**クエリパラメータ**しか伏せない。どちらも
    # 「`command:` という値の中に埋まった URL」には効かない（#65）。
    #
    # ⚠ 本筋は pooza/ginseng-core 側に「ログ時に伏せる引数」の口を持たせること。
    # ここはそれが入るまでの受け皿。
    def secrets
      return @secrets ||= []
    end

    def secrets=(values)
      @secrets = values.to_a.compact.reject(&:blank?)
    end

    def masked(text)
      return secrets.inject(text.to_s) do |dest, secret|
        [secret.to_s, secret.to_s.shellescape].uniq.inject(dest) do |masked, pattern|
          masked.gsub(pattern, FILTERED)
        end
      end
    end

    private

    # ⚠ Ginseng::CommandLine#log_exec と同じ形。command だけ伏せてから出す。
    def log_exec(secs, success:)
      params = {
        command: masked(to_s), dir:, env: @env, user: @user,
        status: @status, seconds: secs.round(3)
      }
      success ? @logger.info(params) : @logger.error(params)
    end
  end
end
