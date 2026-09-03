module WritersBase
  class LoggerTest < TestCase
    WEBHOOK = 'https://mulukhiya.example/webhook/9f3c1b7e'.freeze

    def setup
      @logger = Logger.new
    end

    def entry(message)
      return @logger.send(:create_entry, message)
    end

    # ⚠⚠ マスクを通せないと fail closed で `_mask_error` になり、**ログが丸ごと
    # 読めなくなる**。以前は WritersBase::Logger#mask が Ginseng::Masking#mask と
    # 名前衝突していて（こちらは引数を取らない）、全行がこの形だった（#66）
    def test_leaves_plain_message
      parsed = JSON.parse(entry({tool: 'postgresql_dump', db: 'mastodon'}))

      assert_false(parsed.key?('_mask_error'))
      assert_equal('postgresql_dump', parsed['tool'])
    end

    def test_masks_env_password
      assert_not_match(/hunter2secret/, entry({env: {'PGPASSWORD' => 'hunter2secret'}}))
      assert_not_match(/hunter2secret/, entry({env: {'MYSQL_PWD' => 'hunter2secret'}}))
    end

    # ⚠ キー名でしか見ないマスクでは、値の中に埋まった資格情報に効かない
    def test_masks_token_in_query
      assert_not_match(/abcdef123456/, entry({url: 'https://example.com/api?access_token=abcdef123456'}))
    end

    # ⚠ モロヘイヤの webhook URL はダイジェストが**クエリではなくパス**に載る（#65）
    def test_masks_webhook_path
      assert_not_match(/9f3c1b7e/, entry({command: "tootctl emoji sync --webhook #{WEBHOOK}"}))
    end
  end
end
