module WritersBase
  # 再起動待ちを判定し、溜まっていれば heartbeat を down にする（#141）。
  #
  # ⚠⚠ **再起動待ちは「失敗」ではない**ので、Sentry にも #91 の「失敗・不実行」にも乗らない。
  # 以前は文字列を返すだけで heartbeat は常に `up / OK` だったため、**あるノードは 20 週間・
  # カーネル 9 世代ぶん**溜めていた（pooza/chubo2 の 2026-09-18 の棚卸し）。
  #
  # | 状態 | heartbeat |
  # | --- | --- |
  # | 正常 | `up` / `OK` |
  # | 要再起動（しきい値未満） | `up` / `OK 要再起動(...)` |
  # | 要再起動（しきい値以上） | 🔴 `down` / `要再起動(...)` |
  #
  # 🔴 **直近の 1 世代では鳴らさない。**鳴らすと「鳴っているが対処しなくてよいもの」になり、
  # また読まれなくなる。しきい値と文面は chubo-core の monit（`kuma-push.erb`）に揃えてある。
  class RebootRequiredTool < Tool
    DEBIAN_FLAG = '/var/run/reboot-required'.freeze
    DEBIAN_PKGS = '/var/run/reboot-required.pkgs'.freeze
    DPKG_INFO_DIR = '/var/lib/dpkg/info'.freeze
    FREEBSD_KERNEL = '/boot/kernel/kernel'.freeze

    def exec(args = {})
      @pending = pending
      return @pending.to_s
    end

    def description
      return 'システムに再起動が必要かを判定します。'
    end

    def status_message
      return 'OK' unless @pending
      return "OK #{@pending}"
    end

    def alert
      return nil unless @pending
      return nil if wait_days < stale_days
      return @pending
    end

    private

    # ⚠⚠ 未対応のプラットフォームで `nil`（＝「再起動は不要」）を返さない（#122）。
    # #63 で塞いだ「uname が落ちると常に不要へ倒れる」と同じ型。
    def pending
      case platform_family
      when :freebsd
        return freebsd_pending
      when :debian
        return debian_pending
      end
    end

    # ⚠ uname / freebsd-version が失敗すると空文字どうしの比較になり、
    # 「常に再起動不要」へ倒れていた。落ちたら黙らず例外にする（#63）。
    def freebsd_pending
      running = execute(['uname', '-r']).stdout.to_s.strip
      installed = execute(['freebsd-version', '-k']).stdout.to_s.strip
      return nil if running == installed
      return "要再起動(#{running}→#{installed}/待ち#{wait_days}日)"
    end

    def debian_pending
      return nil unless File.exist?(DEBIAN_FLAG)
      return "要再起動(待ち#{wait_days}日)"
    end

    # ⚠⚠ **稼働日数ではなく「再起動待ちになってからの日数」**（#160）。稼働日数で見ると、
    # 長く動いている台に今日カーネルが入っただけで即 down になり、しきい値を 14 日まで
    # 下げられない（#141 では 42 日の稼働日数で近似していた）。
    # chubo-core の monit（`kuma-push.erb`）・chubo2 の `reboot-sweep.rb` と同じ測り方。
    def wait_days
      @wait_days ||= ((Time.now - wait_since) / 86_400).floor
      return @wait_days
    end

    # ⚠ 待ち始めは起動より前に遡らせない。取れなければ起動時刻（＝ 稼働日数）に戻す。
    # 稼働日数は待ち日数の上限なので、戻したときは「鳴りやすい」側へ倒れる。
    def wait_since
      since = platform_family == :freebsd ? freebsd_wait_since : debian_wait_since
      return [since, boot_time].compact.max
    end

    # ⚠ 導入済みカーネルの mtime。`freebsd-update install` を 2 回すると後のほうになり、
    # 短めに出る（手で入れる運用なので許容・chubo-core と同じ）。
    def freebsd_wait_since
      return nil unless File.exist?(freebsd_kernel)
      return File.mtime(freebsd_kernel)
    end

    # ⚠⚠ `/var/run/reboot-required` の mtime を使わないこと。**更新のたびに touch し直される**ので、
    # 溜めている台ほど「待ち 0 日」に見える。
    # `.pkgs` に載っているパッケージの導入時刻（dpkg の `.list` の mtime）のうち、
    # **起動より後で最も古いもの**を待ち始めにする。古いカーネルは再導入されないので、
    # 何世代溜まっても最初の 1 本の時刻が残る。起動前のもの（`linux-base` など）は待ちの原因ではない。
    # ⚠ 起動後に同じパッケージ（`libc6` など）を 2 回上げていると、`.list` は後の時刻なので短めに出る。
    def debian_wait_since
      return nil unless File.exist?(debian_pkgs)
      boot = boot_time
      lists = Dir.children(dpkg_info_dir)
      return File.readlines(debian_pkgs, chomp: true).map(&:strip).reject(&:empty?).uniq
          .flat_map {|pkg| dpkg_lists(lists, pkg)}
          .map {|path| File.mtime(path)}
          .select {|mtime| mtime > boot}
          .min
    end

    # `<pkg>.list` と、マルチアーチの `<pkg>:<arch>.list` の両方を拾う
    def dpkg_lists(names, pkg)
      names = names.select do |name|
        name == "#{pkg}.list" || (name.start_with?("#{pkg}:") && name.end_with?('.list'))
      end
      return names.map {|name| File.join(dpkg_info_dir, name)}.select {|path| File.file?(path)}
    end

    def debian_pkgs = DEBIAN_PKGS
    def dpkg_info_dir = DPKG_INFO_DIR
    def freebsd_kernel = FREEBSD_KERNEL

    def boot_time
      @boot_time ||= read_boot_time
      return @boot_time
    end

    # ⚠⚠ `kern.boottime` は `{ sec = ..., usec = ... }`。`.*sec = ` で抜くと貪欲マッチが
    # `usec` を拾う（chubo2 の reboot-sweep が全 FreeBSD を 20,712 日と出していた）。
    def read_boot_time
      case platform_family
      when :freebsd
        sec = execute(['sysctl', '-n', 'kern.boottime']).stdout.to_s[/\A\{ *sec = (\d+)/, 1]
        raise 'kern.boottime を読めません' unless sec
        return Time.at(sec.to_i)
      when :debian
        return Time.now - File.read('/proc/uptime').split.first.to_f
      end
    end
  end
end
