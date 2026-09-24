module WritersBase
  class MisskeyEmojiSyncToolTest < TestCase
    def setup
      @tool = Tool.create('misskey_emoji_sync')
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # 未設定のキーで落ちない。Ginseng::Configは例外を投げるので、
    # 「告知しない」という正当な設定をエラーと取り違えないこと
    def test_setting_returns_nil_when_absent
      assert_nil(@tool.send(:setting, :nonexistent))
    end

    # originが無ければtootctlを組み立てる前に落とす。設定を忘れた機体で
    # 「毎日静かに何もしない」状態にならないようにする
    def test_execute_without_origin
      assert_raise(Ginseng::ConfigError) {@tool.exec} if @tool.send(:setting, :origin).blank?
    end

    def test_login_shell
      command = @tool.send(:login_command, ['bundle', 'check'])

      assert_match(/\Abash -lc /, command.to_s)
    end

    # webhookが無ければ--webhookを付けない（従来どおり告知しない）
    def test_tootctl_args_without_webhook
      args = @tool.send(:tootctl_args, 'https://misskey.example')

      assert_equal(['emoji', 'sync', 'https://misskey.example', '--no-dry-run'], args) if @tool.send(:setting, :webhook).blank?
    end

    # 出力の要点だけを拾う。初回同期の数百件のショートコードをログへ流さない
    def test_report_keeps_only_summary_lines
      stdout = [
        'Syncing custom emoji from misskey.example',
        '  copy fresh',
        'Copied 1, recategorized 0, removed 0 empty categories',
        'Posted announcement.',
      ].join("\n")

      assert_equal(
        ['Copied 1, recategorized 0, removed 0 empty categories', 'Posted announcement.'],
        @tool.send(:report, stdout),
      )
    end

    WEBHOOK = 'https://mulukhiya.example/mulukhiya/webhook/9f3c1b7e'.freeze

    STDOUT_WITH_DRAFTS = [
      'Syncing custom emoji from misskey.example',
      'Copied 2, recategorized 0, removed 0 empty categories',
      '',
      '--- announcement 1/2 ---',
      '新しい絵文字が届きました',
      ':a:',
      '--- end ---',
      '',
      '--- announcement 2/2 ---',
      '新しい絵文字が届きました',
      ':b:',
      '--- end ---',
      '',
    ].join("\n")

    class ResponseError < StandardError
      Response = Struct.new(:code)

      def response
        return Response.new(403)
      end
    end

    # 🔴 webhook URL をプロセスの引数に載せない（#127）。載せると同居する非 root
    # ユーザから ps で読める。tootctl には下書きを出させるだけ
    def test_tootctl_args_with_webhook
      config['/misskey_emoji_sync/webhook'] = WEBHOOK
      args = @tool.send(:tootctl_args, 'https://misskey.example')

      assert_equal(['emoji', 'sync', 'https://misskey.example', '--no-dry-run', '--announce'], args)
      assert_not_include(args, '--webhook')
      assert_not_match(/9f3c1b7e/, args.join(' '))
    end

    # ⚠⚠ マスクの接頭辞に当たらない URL は、ログの url: に素のまま出る（Codex P2）。
    # tootctl を走らせる前に設定エラーで止め、文面にも URL を出さない
    def test_unmasked_webhook
      config['/misskey_emoji_sync/origin'] = 'https://misskey.example'
      config['/misskey_emoji_sync/webhook'] = 'https://hooks.slack.example/services/T0/B0/9f3c1b7e'
      error = assert_raise(Ginseng::ConfigError) {@tool.exec}

      assert_not_match(/9f3c1b7e/, error.message)
    end

    def test_webhook_masked
      assert_true(@tool.send(:webhook_masked?)) if @tool.send(:setting, :webhook).blank?
      config['/misskey_emoji_sync/webhook'] = WEBHOOK

      assert_true(@tool.send(:webhook_masked?))
    end

    def test_drafts
      drafts = @tool.send(:drafts, STDOUT_WITH_DRAFTS)

      assert_equal(['announcement 1/2', 'announcement 2/2'], drafts.map {|v| v[:label]})
      assert_equal("新しい絵文字が届きました\n:a:", drafts.first[:text])
    end

    def test_drafts_without_announcement
      assert_equal([], @tool.send(:drafts, "Copied 0, recategorized 0, removed 0 empty categories\nNothing to announce.\n"))
    end

    def test_post_drafts
      posted = []
      @tool.define_singleton_method(:post_draft) {|text| posted.push(text)}
      result = {report: [], failure: []}
      @tool.send(:post_drafts, @tool.send(:drafts, STDOUT_WITH_DRAFTS), result)

      assert_equal(2, posted.size)
      assert_equal(['Posted announcement 1/2.', 'Posted announcement 2/2.'], result[:report])
      assert_equal([], result[:failure])
    end

    # ⚠⚠ tootctl の --webhook は投稿に失敗しても exit 0 で黙って消えていた。
    # こちらでは failure に積んで Sentry / Kuma へ届ける。⚠ 文面に URL を出さない
    def test_post_drafts_failure
      config['/misskey_emoji_sync/webhook'] = WEBHOOK
      @tool.define_singleton_method(:post_draft) {|_text| raise ResponseError, "Bad response 403 (#{WEBHOOK})"}
      result = {report: [], failure: []}
      @tool.send(:post_drafts, @tool.send(:drafts, STDOUT_WITH_DRAFTS), result)

      assert_equal(2, result[:failure].size)
      assert_equal('HTTP 403', result[:failure].first[:error])
      assert_true(@tool.instance_variable_set(:@result, result) && @tool.failed?)
      assert_not_match(/9f3c1b7e/, result.to_s)
    end

    def test_post_error_without_response
      assert_equal('SocketError', @tool.send(:post_error, SocketError.new(WEBHOOK)))
    end
  end
end
