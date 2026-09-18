module WritersBase
  class HeartbeatTest < TestCase
    TOKEN = 'testtoken20260919'.freeze

    def setup
      @heartbeat = Heartbeat.new('postgresql_dump')
      config['/heartbeat/tokens/postgresql_dump'] = TOKEN
    end

    # ⚠ トークンを書いたツールだけ送る。書いていないノードでは何もしない
    def test_disabled_without_token
      config.delete('/heartbeat/tokens/postgresql_dump')

      assert_true(@heartbeat.disable?)
      assert_nil(@heartbeat.up)
    end

    def test_enabled_with_token
      assert_false(@heartbeat.disable?)
    end

    # 🔴 成功時も送る。push モニタは「途切れたら DOWN」という向きなので、
    # 成功を送らないと「走った」ことが伝わらない（#91）
    def test_up_sends_status_up
      args = @heartbeat.up.args

      assert_equal('curl', args.first)
      assert_include(args, 'status=up')
      assert_include(args, 'msg=OK')
      assert_equal(File.join('https://uptime.b-shock.org/api/push', TOKEN), args.last)
    end

    def test_down_sends_status_down
      args = @heartbeat.down('postgresql_dump が 1 件失敗しました').args

      assert_include(args, 'status=down')
      assert_include(args, 'msg=postgresql_dump が 1 件失敗しました')
    end

    # ⚠⚠ push URL はそれ自体が資格情報。ログにも例外にも出さない（#65 と同じ経路）
    def test_url_is_masked_in_log
      command = @heartbeat.up

      assert_not_match(Regexp.new(TOKEN), command.masked(command.to_s))
    end

    # ⚠ Kuma の msg は一覧に出る。長い stderr を丸ごと送らない
    def test_message_is_summarized
      args = @heartbeat.down("#{'a' * 500}\n\nbbb").args
      msg = args.find {|arg| arg.to_s.start_with?('msg=')}

      assert_true(msg.length <= Heartbeat::MESSAGE_LIMIT + 4)
    end

    # ⚠ 失敗の本文には資格情報が載りうる。Sentry へ送る前と同じ網を通す（#37 / #65）
    def test_message_is_scrubbed
      args = @heartbeat.down('MYSQL_PWD=hunter2secret mysqldump ...').args

      assert_not_match(/hunter2secret/, args.join(' '))
    end
  end
end
