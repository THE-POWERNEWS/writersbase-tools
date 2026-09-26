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
      assert_equal({status: 'up', msg: 'OK'}, @heartbeat.up)
    end

    # 要対応の手前の状態を up の msg に載せられる（#141）
    def test_up_with_message
      assert_equal({status: 'up', msg: 'OK 要再起動(稼働3日)'}, @heartbeat.up('OK 要再起動(稼働3日)'))
    end

    def test_down_sends_status_down
      query = @heartbeat.down('postgresql_dump が 1 件失敗しました')

      assert_equal('down', query[:status])
      assert_equal('postgresql_dump が 1 件失敗しました', query[:msg])
    end

    # ⚠⚠ **push URL はそれ自体が資格情報で、トークンはパスに入る（#91）。**
    # 🔴 **以前は curl の引数に載せていたので `ps` から読めた（#121）。**
    # いまは Ruby 側から送るので、**どのプロセスの引数にも載らない。**
    def test_token_is_not_passed_as_argument
      query = @heartbeat.up

      assert_kind_of(Hash, query)
      assert_not_match(Regexp.new(TOKEN), query.to_s)
    end

    # ⚠ ログに出る経路（Ginseng::HTTP#log の `url:`）でトークンが伏せられること。
    # ⚠⚠ **マスクの正本は Ginseng::Masking** なので、道具側で同等品を書かず
    # `/logger/mask_url_paths` で足す（#121）。
    def test_url_is_masked_in_log
      entry = Logger.new.send(:create_entry, {method: :GET, url: @heartbeat.send(:url)})

      assert_not_match(Regexp.new(TOKEN), entry)
      assert_match(%r{/api/push/}, entry)
    end

    # ⚠ 例外の本文には URL がそのまま載る（HTTParty / GatewayError）
    def test_error_message_is_masked
      masked = @heartbeat.send(:masked, "Bad response 403 (#{@heartbeat.send(:url)})")

      assert_not_match(Regexp.new(TOKEN), masked)
    end

    # ⚠⚠ 空のトークンで gsub すると 1 文字ごとに印が挟まる
    def test_masked_without_token
      config.delete('/heartbeat/tokens/postgresql_dump')

      assert_equal('plain text', @heartbeat.send(:masked, 'plain text'))
    end

    # ⚠⚠ **再送しない。**`down` は Sentry へ送るより手前で呼ばれるので、
    # 通知が詰まっているときに失敗の報告そのものが遅れる（#121）
    def test_http_does_not_retry
      assert_equal(1, @heartbeat.send(:http).retry_limit)
    end

    # ⚠ Kuma の msg は一覧に出る。長い stderr を丸ごと送らない
    def test_message_is_summarized
      query = @heartbeat.down("#{'a' * 500}\n\nbbb")

      assert_true(query[:msg].length <= Heartbeat::MESSAGE_LIMIT)
    end

    # ⚠ 失敗の本文には資格情報が載りうる。Sentry へ送る前と同じ網を通す（#37 / #65）
    def test_message_is_scrubbed
      query = @heartbeat.down('MYSQL_PWD=hunter2secret mysqldump ...')

      assert_not_match(/hunter2secret/, query[:msg])
    end
  end
end
