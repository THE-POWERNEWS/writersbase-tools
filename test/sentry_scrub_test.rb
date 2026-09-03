module WritersBase
  class SentryScrubTest < TestCase
    def build_event(message)
      event = Sentry::ErrorEvent.new(configuration: Sentry::Configuration.new)
      exception = RuntimeError.new(message)
      exception.set_backtrace(caller)
      event.add_exception_interface(exception, mechanism: Sentry::Mechanism.new)
      return event
    end

    def scrubbed(message)
      return WritersBase.scrub_sentry_event(build_event(message), {})
          .exception.values.first.value
    end

    def test_env_password
      result = scrubbed('MYSQL_PWD=hunter2secret mysqldump failed')

      assert_not_match(/hunter2secret/, result)
      assert_match(/MYSQL_PWD=\[FILTERED\]/, result)
    end

    def test_token_in_query
      result = scrubbed('GET /v1/articles?access_token=abc123XYZ456 failed')

      assert_not_match(/abc123XYZ456/, result)
    end

    def test_url_credentials
      # ⚠ URL の形をしたものは Ginseng::Masking が落とす
      result = scrubbed('connect postgres://postgres:hunter2secret@localhost/db failed')

      assert_not_match(/hunter2secret/, result)
    end

    def test_stacktrace_context_line
      # ⚠ Sentry は例外が起きた行の前後のソースも送る。メッセージだけ伏せても足りない。
      event = build_event('failed')
      frame = event.exception.values.first.stacktrace.frames.first
      frame.context_line = 'cmd = "MYSQL_PWD=hunter2secret mysqldump"'
      result = WritersBase.scrub_sentry_event(event, {})

      assert_not_match(
        /hunter2secret/,
        result.exception.values.first.stacktrace.frames.first.context_line,
      )
    end

    # ⚠ webhook URL はダイジェストが**パス**に載るので、クエリを見るマスクでは
    # 伏せられない。CommandLine#secrets の漏れに対する保険（#65）
    def test_webhook_option
      result = scrubbed('tootctl emoji sync --webhook https://mulukhiya.example/webhook/9f3c1b7e failed')

      assert_not_match(/9f3c1b7e/, result)
      assert_match(/--webhook \[FILTERED\]/, result)
    end

    def test_preserves_plain_message
      assert_match(/zstd が見つかりません/, scrubbed('zstd が見つかりません'))
    end

    def test_no_exception
      event = Sentry::ErrorEvent.new(configuration: Sentry::Configuration.new)

      assert_not_nil(WritersBase.scrub_sentry_event(event, {}))
    end
  end
end
