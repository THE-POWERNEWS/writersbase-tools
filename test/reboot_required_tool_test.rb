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

    PENDING = '要再起動(14.5-RELEASE→15.1-RELEASE/待ち14日)'.freeze

    def stub_pending(pending, days)
      @tool.define_singleton_method(:pending) {pending}
      @tool.instance_variable_set(:@wait_days, days)
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

    DAY = 86_400

    def stub_boot(platform, days_ago)
      boot = Time.now - (days_ago * DAY)
      @tool.define_singleton_method(:platform_family) {platform}
      @tool.define_singleton_method(:boot_time) {boot}
      return boot
    end

    def stub_debian(dir, pkgs, lists)
      File.write(File.join(dir, 'reboot-required.pkgs'), pkgs.map {|v| "#{v}\n"}.join)
      info = File.join(dir, 'info')
      Dir.mkdir(info)
      lists.each do |name, mtime|
        path = File.join(info, name)
        File.write(path, '')
        File.utime(mtime, mtime, path)
      end
      @tool.define_singleton_method(:debian_pkgs) {File.join(dir, 'reboot-required.pkgs')}
      @tool.define_singleton_method(:dpkg_info_dir) {info}
    end

    # ⚠⚠ 稼働日数ではなく待ち日数（#160）。起動後に入った `.pkgs` のうち最も古いもの。
    # 起動前のもの（linux-base）は待ちの原因ではないので除く。マルチアーチの `.list` も拾う
    def test_debian_wait_days
      Dir.mktmpdir do |dir|
        boot = stub_boot(:debian, 30)
        stub_debian(dir, ['linux-image-7.0.0-34-generic', 'libc6', 'linux-base', 'libc6'], {
          'linux-image-7.0.0-34-generic.list' => boot + (25 * DAY),
          'libc6:amd64.list' => boot + (10 * DAY),
          'libc6-dev:amd64.list' => boot + (1 * DAY),
          'linux-base.list' => boot - (100 * DAY),
        })

        assert_equal(20, @tool.send(:wait_days))
      end
    end

    # 待ち始めが取れなければ稼働日数に戻す（上限なので「鳴りやすい」側）
    def test_debian_wait_days_fallback
      Dir.mktmpdir do |dir|
        boot = stub_boot(:debian, 30)
        stub_debian(dir, ['linux-base'], {'linux-base.list' => boot - DAY})

        assert_equal(30, @tool.send(:wait_days))
      end
    end

    def test_freebsd_wait_days
      Dir.mktmpdir do |dir|
        boot = stub_boot(:freebsd, 60)
        kernel = File.join(dir, 'kernel')
        File.write(kernel, '')
        File.utime(boot + (45 * DAY), boot + (45 * DAY), kernel)
        @tool.define_singleton_method(:freebsd_kernel) {kernel}

        assert_equal(15, @tool.send(:wait_days))
      end
    end

    # ⚠ 待ち始めは起動より前に遡らせない
    def test_freebsd_wait_days_capped_by_uptime
      Dir.mktmpdir do |dir|
        boot = stub_boot(:freebsd, 10)
        kernel = File.join(dir, 'kernel')
        File.write(kernel, '')
        File.utime(boot - (90 * DAY), boot - (90 * DAY), kernel)
        @tool.define_singleton_method(:freebsd_kernel) {kernel}

        assert_equal(10, @tool.send(:wait_days))
      end
    end

    def test_freebsd_boot_time_unreadable
      @tool.define_singleton_method(:platform_family) {:freebsd}
      @tool.define_singleton_method(:execute) {|_args| Struct.new(:stdout).new('')}

      assert_raise(RuntimeError) {@tool.send(:boot_time)}
    end
  end
end
