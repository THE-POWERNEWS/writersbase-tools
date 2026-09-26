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
      return nil if @uptime_days < stale_days
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
      return "要再起動(#{running}→#{installed}/稼働#{uptime_days}日)"
    end

    def debian_pending
      return nil unless File.exist?(DEBIAN_FLAG)
      return "要再起動(稼働#{uptime_days}日)"
    end

    # ⚠⚠ **「待っている日数」ではなく稼働日数で近似する。**いつ待ちに入ったかは分からない。
    # `/var/run/reboot-required` の mtime は更新が入るたびに touch し直されるので、
    # 更新が続くノードほど日数が戻り、**溜めているノードほど鳴らない**。
    # 稼働日数は待ち日数の上限なので、鳴るのは「少なくともそれだけ再起動していない」とき。
    # chubo-core の monit / chubo2 の `reboot-sweep.rb` も同じ近似。
    def uptime_days
      @uptime_days ||= ((Time.now - boot_time) / 86_400).floor
      return @uptime_days
    end

    # ⚠⚠ `kern.boottime` は `{ sec = ..., usec = ... }`。`.*sec = ` で抜くと貪欲マッチが
    # `usec` を拾う（chubo2 の reboot-sweep が全 FreeBSD を 20,712 日と出していた）。
    def boot_time
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
