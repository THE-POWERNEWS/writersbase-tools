module WritersBase
  class Tool
    attr_reader :logger, :config

    # 失敗の文字列に残す先頭・末尾の文字数（`abbreviate`・#119）
    ERROR_HEAD = 200
    ERROR_TAIL = 700

    def exec(args = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def body(args = {})
      result = @result = exec(args)
      # ⚠ failure が詰まっていても info で出していたため、ログを見ても異常が目立たなかった
      failed? ? logger.error(tool: underscore, result:) : logger.info(tool: underscore, result:)
      contents = []
      if result.is_a?(String)
        contents.push(result)
      else
        contents.push(JSON.pretty_generate(result))
      end
      return contents.join("\n")
    end

    # ⚠ 各ツールは失敗を自分で握って `result[:failure]` に積み、正常に return する。
    # 握られた失敗を呼び出し側（bin/wb）から拾えるようにしておく（#64）。
    def failures
      return [] unless @result.is_a?(Hash)
      return @result[:failure].to_a
    end

    def failed?
      return failures.present?
    end

    # ⚠ 1 回の実行で N 件失敗しても、Sentry へは 1 件にまとめて送る
    # （DB ごとに別 issue にしない）。
    def failure_error
      message = "#{underscore} が #{failures.size} 件失敗しました"
      return ToolError.new("#{message} (#{failure_details.join(' / ')})")
    end

    def failure_details
      return failures.map do |failure|
        next failure.to_s unless failure.is_a?(Hash)
        next failure.map {|k, v| "#{k}: #{v}"}.join(', ')
      end
    end

    def underscore
      return self.class.to_s.underscore.split('/').last.sub(/_tool$/, '')
    end

    def description
      return "#{underscore} のヘルプは未定義"
    end

    def help
      return ["bin/wb #{underscore}", "  #{description}", '']
    end

    def test?
      return Environment.test?
    end

    def self.create(name)
      return "WritersBase::#{name.camelize}Tool".constantize.new
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Dir.glob(File.join(Environment.dir, 'app/lib/writers_base/tool/*.rb')).each do |path|
        yield create(File.basename(path, '.rb').sub('_tool', ''))
      end
    end

    private

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    def compress(path)
      logger.info(tool: underscore, path:, message: '圧縮開始')
      execute(['zstd', "-#{config['/zstd/level']}", '--rm', '-f', path])
      logger.info(tool: underscore, path:, message: '圧縮終了')
      return "#{path}.zst"
    end

    # 外部コマンドを実行し、非ゼロ終了なら例外にする。
    # ⚠⚠ Ginseng::CommandLine#exec は status を返すだけで例外を投げないので、
    # 呼び出し側が見なければ失敗が消える（「消していないのに消した」と記録する類）。
    # CommandLine の直呼びを増やさず、外部コマンドは必ずここを通すこと（#63）。
    def execute(args, env: {}, user: nil, dir: nil, secrets: [])
      command = CommandLine.new(args)
      command.env = env
      command.user = user if user
      command.dir = dir if dir
      command.secrets = secrets
      return command if test?
      command.exec
      raise command_error(command) unless command.status.zero?
      return command
    end

    # パイプラインを、途中の失敗を落とさないシェルで実行するための引数を組み立てる。
    # ⚠⚠ `sh` が返すのは末尾のコマンドの status だけなので、`pg_dump | zstd > path` は
    # **pg_dump が落ちても 0** になる。zstd は空の入力でも正しい .zst を書くため、
    # もっともらしいサイズの小さいファイルが残り、失敗が success として記録される（#62）。
    # ⚠ bash に依存する。FreeBSD では base に無いので、chubo-core が依存として入れる
    # （入っていないノードでは `sh: bash: not found` で落ちる。pirazis で実例あり）。
    def pipefail_args(args)
      return ['bash', '-o', 'pipefail', '-c', CommandLine.new(args).to_s]
    end

    # ⚠ pipefail で拾えない壊れ方に備え、書けたファイル自体を確かめる。
    def verify_archive(path)
      raise "#{path} が作られていません" unless File.exist?(path)
      raise "#{path} が空です" if File.empty?(path)
      execute(['zstd', '-t', path])
      return path
    end

    # ⚠ 何も言わずに落ちるコマンド（zfs destroy 等）があるので、stderr が空でも
    # 「どのコマンドがどう落ちたか」は必ず残す。
    def command_error(command)
      # ⚠ 資格情報は stderr にも載りうるので、例外へ移すときも伏せる（#65）
      # ⚠⚠ **伏せてから切る。**逆にすると、資格情報の途中で切れた断片が伏せられずに残る
      return abbreviate(command.masked(command.stderr.strip)) if command.stderr.present?
      return "#{command.args.first} が異常終了しました (#{exit_status_text(command)})"
    end

    # ⚠⚠ **stderr を丸ごと載せると、原因が残らない**（#119）。実測で、journald（Ubuntu）は
    # 300 KB を超える行を**行ごと捨て**、FreeBSD の syslogd は **8,087 バイト**で、
    # Sentry は **1,024 文字**で切り詰める。🔴 3 経路とも**先頭しか残らない**が、
    # rclone は**原因を末尾に書く**（`--verbose` の NOTICE が先頭を埋め、
    # `rateLimitExceeded` が 1 件も見えなかった ＝ #99 の誤読の経路）。
    # ⚠ 頭だけ切ると今と同じになるので、**先頭と末尾を両方残す**。
    # ⚠ 合計は Sentry の 1,024 文字を下回る値にしてある。`failure_error` が付ける
    # 前置き（`… が 1 件失敗しました (src: /etc, error: `）を足しても、失敗 1 件なら末尾まで見える。
    def abbreviate(text, head: ERROR_HEAD, tail: ERROR_TAIL)
      return text if text.length <= head + tail
      omitted = text.length - head - tail
      return "#{text[0, head]}\n…（#{omitted} 文字省略）…\n#{text[-tail..]}"
    end

    # ⚠ Ginseng::CommandLine#status は Process::Status#to_i の生値で、終了コードでは
    # ない（`exit 3` は 768 = 3 << 8）。ログの数字をそのまま終了コードと読まないこと。
    def exit_status_text(command)
      signal = command.status & 0x7f
      return "signal #{signal}" if signal.nonzero?
      return "exit #{command.status >> 8}"
    end

    def method_missing(method, *args)
      return config["/#{underscore}/#{method}"] if args.empty?
      return super
    end

    def respond_to_missing?(method, *args)
      return args.empty? if args.is_a?(Array)
      return super
    end

    # ⚠ 未対応のプラットフォームで `nil` を返すと、`FileUtils.chown('root', nil, path)` は
    # **group を変えずに成功する**（#122）。判定は `Environment.platform_family` が例外にする。
    def root_group
      case platform_family
      when :freebsd
        return 'wheel'
      when :debian
        return 'adm'
      end
    end

    def platform_family
      return Environment.platform_family
    end
  end
end
