module WritersBase
  class ToolTest < TestCase
    def setup
      @tool = Tool.create('help')
    end

    def test_all
      Tool.all do |tool|
        assert_kind_of(Tool, tool)
      end
    end

    # ⚠ Ginseng::CommandLine#exec は status を返すだけで例外を投げない。
    # 落ちたコマンドを success として記録しないよう、Tool#execute で例外にする（#63）
    def test_command_error_uses_stderr
      command = CommandLine.new(['sh', '-c', 'echo boom >&2; exit 3'])
      command.exec

      assert_equal('boom', @tool.send(:command_error, command))
    end

    # ⚠⚠ 道具は失敗を自分で握って result[:failure] に積み、正常に return する。
    # 握られた失敗を拾えないと、Sentry へ飛ばず終了コードも 0 になる（#64）
    def test_failed_with_failures
      @tool.instance_variable_set(:@result, {
        success: [],
        failure: [{db: 'mastodon', error: 'pg_dump が異常終了しました (exit 1)'}],
      })

      assert_true(@tool.failed?)
      assert_match(/mastodon/, @tool.failure_error.message)
      assert_match(/1 件失敗/, @tool.failure_error.message)
    end

    def test_failed_without_failures
      @tool.instance_variable_set(:@result, {success: ['/backup/mastodon.sql.zst'], failure: []})

      assert_false(@tool.failed?)
    end

    # help や reboot_required のように String を返す道具もある
    def test_failed_with_string_result
      @tool.instance_variable_set(:@result, '再起動が必要')

      assert_false(@tool.failed?)
    end

    # ⚠⚠ `sh` はパイプラインの末尾の status しか返さないので、`pg_dump | zstd > path` は
    # pg_dump が落ちても 0 になる。bash の pipefail を明示して拾う（#62）
    def test_pipefail_args
      args = @tool.send(:pipefail_args, ['false', :|, 'zstd', '-3', :>, '/tmp/dump.zst'])

      assert_equal(['bash', '-o', 'pipefail', '-c', 'false | zstd -3 > /tmp/dump.zst'], args)
    end

    # ⚠ 資格情報は stderr にも載りうるので、例外へ移すときも伏せる（#65）
    def test_command_error_masks_secrets
      command = CommandLine.new(['sh', '-c', 'echo https://mulukhiya.example/webhook/9f3c1b7e >&2; exit 1'])
      command.secrets = ['https://mulukhiya.example/webhook/9f3c1b7e']
      command.exec

      assert_not_match(/9f3c1b7e/, @tool.send(:command_error, command))
    end

    # ⚠⚠ rclone は原因を末尾に書く。先頭だけ残すと --verbose の NOTICE に埋もれ、
    # rateLimitExceeded が 1 件も見えない（#119・#99 の誤読の経路）
    def test_command_error_keeps_tail
      command = CommandLine.new(['sh', '-c', 'yes NOTICE | head -n 50000 >&2; echo rateLimitExceeded >&2; exit 1'])
      command.exec
      message = @tool.send(:command_error, command)

      assert_match(/rateLimitExceeded\z/, message)
      assert_match(/\ANOTICE/, message)
      assert_match(/文字省略/, message)
      assert_operator(message.length, :<, 1000)
    end

    def test_abbreviate_short_text
      assert_equal('boom', @tool.send(:abbreviate, 'boom'))
    end

    # ⚠⚠ 伏せてから切る。切ってから伏せると、境界で切れた資格情報の断片が残る。
    # 資格情報が「先頭の保持範囲」の切れ目をまたぐ位置に置いて確かめる
    def test_command_error_masks_before_abbreviate
      secret = "https://mulukhiya.example/webhook/#{'9f3c1b7e' * 20}"
      stderr = "#{'x' * (Tool::ERROR_HEAD - 50)}#{secret}#{'y' * 5000}"
      command = CommandLine.new(['sh', '-c', "printf %s #{stderr} >&2; exit 1"])
      command.secrets = [secret]
      command.exec

      assert_not_match(/9f3c1b7e/, @tool.send(:command_error, command))
    end

    # ⚠ Sentry は 1,024 文字で切るので、失敗 1 件ならまとめた例外の末尾まで収まること
    def test_failure_error_fits_sentry
      command = CommandLine.new(['sh', '-c', 'yes NOTICE | head -n 50000 >&2; echo rateLimitExceeded >&2; exit 1'])
      command.exec
      @tool.instance_variable_set(:@result, {
        success: [],
        failure: [{src: '/home/misskey/repos/mulukhiya-toot-proxy', error: @tool.send(:command_error, command)}],
      })
      message = @tool.failure_error.message

      assert_operator(message.length, :<=, 1024)
      assert_match(/rateLimitExceeded\)\z/, message)
    end

    # ⚠ zfs destroy のように何も言わずに落ちるコマンドがあるので、stderr が空でも
    # 「どのコマンドがどう落ちたか」は残す。⚠ CommandLine#status は生値（3 なら 768）
    # なので、そのまま出さずに終了コードへ直す
    def test_command_error_without_stderr
      command = CommandLine.new(['sh', '-c', 'exit 3'])
      command.exec

      assert_match(/exit 3/, @tool.send(:command_error, command))
    end
  end
end
