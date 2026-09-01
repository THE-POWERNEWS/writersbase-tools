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
  end
end
