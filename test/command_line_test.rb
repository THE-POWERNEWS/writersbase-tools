module WritersBase
  class CommandLineTest < TestCase
    WEBHOOK = 'https://mulukhiya.example/webhook/9f3c1b7e'.freeze

    # ログの宛先は syslog なので、実際に渡される値を見るために logger を差し替える
    class LoggerSpy
      attr_reader :messages

      def initialize
        @messages = []
      end

      def info(message)
        @messages.push(message)
      end

      def error(message)
        @messages.push(message)
      end
    end

    def command
      command = CommandLine.new(['bin/tootctl', 'emoji', 'sync', 'https://misskey.example', '--webhook', WEBHOOK])
      command.secrets = [WEBHOOK]
      return command
    end

    # ⚠⚠ webhook URL は URL 自体が資格情報。`--webhook <url>` として引数に載るので、
    # キー名を見るマスクにも、クエリを見るマスクにも引っかからない（#65）
    def test_masked
      assert_not_match(/9f3c1b7e/, command.masked(command.to_s))
      assert_match(/--webhook \[FILTERED\]/, command.masked(command.to_s))
    end

    # ⚠ Ginseng::CommandLine#log_exec は実行のたびに command: を丸ごと出す。
    # 伏せるのはここが本線
    def test_log_exec_masks_secrets
      target = CommandLine.new(['echo', WEBHOOK])
      target.secrets = [WEBHOOK]
      spy = LoggerSpy.new
      target.instance_variable_set(:@logger, spy)
      target.exec

      assert_not_match(/9f3c1b7e/, spy.messages.to_s)
      assert_match(/FILTERED/, spy.messages.to_s)
    end

    # 「告知しない」設定（webhook 未設定）で空文字を伏字に置き換えない
    def test_masked_ignores_blank_secrets
      target = CommandLine.new(['echo', 'hello'])
      target.secrets = [nil, '']

      assert_equal('echo hello', target.masked(target.to_s))
    end
  end
end
