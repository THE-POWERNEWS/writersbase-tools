module WritersBase
  class RebootRequiredToolTest < TestCase
    def setup
      @tool = Tool.create('reboot_required')
    end

    def test_exec
      assert_kind_of(String, @tool.exec)
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ 未対応のプラットフォームで「再起動は不要」と答えない（#122）。
    # #63 で塞いだ「uname が落ちると常に不要へ倒れる」と同じ型
    def test_unsupported_platform
      @tool.define_singleton_method(:platform_family) {Environment.platform_family(:plan9)}

      assert_raise(RuntimeError) {@tool.exec}
    end

    PENDING = '要再起動(14.5-RELEASE→15.1-RELEASE/稼働42日)'.freeze

    def stub_pending(pending, days)
      @tool.define_singleton_method(:pending) {pending}
      @tool.instance_variable_set(:@uptime_days, days)
      @tool.exec
    end

    def test_not_pending
      stub_pending(nil, 100)

      assert_nil(@tool.alert)
      assert_equal('OK', @tool.status_message)
    end

    # 🔴 直近の 1 世代では鳴らさない。しきい値未満は up のまま msg にだけ載せる（#141）
    def test_pending_below_threshold
      config['/reboot_required/stale_days'] = 42
      stub_pending(PENDING, 41)

      assert_nil(@tool.alert)
      assert_equal("OK #{PENDING}", @tool.status_message)
    end

    def test_pending_at_threshold
      config['/reboot_required/stale_days'] = 42
      stub_pending(PENDING, 42)

      assert_equal(PENDING, @tool.alert)
    end

    # ⚠⚠ 再起動待ちは失敗ではない。Sentry と非ゼロ終了の経路（failed?）に乗せない
    def test_pending_is_not_failure
      stub_pending(PENDING, 100)

      assert_false(@tool.failed?)
    end

    # ⚠⚠ `.*sec = ` で抜くと貪欲マッチが usec を拾う（chubo2 の reboot-sweep の前例）
    def test_freebsd_boot_time
      stdout = "{ sec = 1789187343, usec = 249945 } Wed Sep 12 01:09:03 2026\n"
      @tool.define_singleton_method(:platform_family) {:freebsd}
      @tool.define_singleton_method(:execute) {|_args| Struct.new(:stdout).new(stdout)}

      assert_equal(Time.at(1_789_187_343), @tool.send(:boot_time))
    end

    def test_freebsd_boot_time_unreadable
      @tool.define_singleton_method(:platform_family) {:freebsd}
      @tool.define_singleton_method(:execute) {|_args| Struct.new(:stdout).new('')}

      assert_raise(RuntimeError) {@tool.send(:boot_time)}
    end
  end
end
