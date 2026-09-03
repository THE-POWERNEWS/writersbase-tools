module WritersBase
  class Installer
    include Singleton

    attr_reader :logger, :config

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    # ⚠⚠ 失敗しても止まらないが、**握った失敗は必ず返す**。構成管理（itamae）は
    # rake の終了コードしか見ないので、ログに出すだけでは「itamae は緑なのに
    # periodic が 1 本も置かれていない」が起きる（#72）。
    def uninstall
      failures = []
      periods.each do |period|
        Dir.glob(File.join(destroot(period), '*')) do |path|
          next unless File.basename(path).include?(Package.name)
          File.unlink(path)
          logger.info(action: 'uninstall', path:)
        rescue => e
          logger.error(action: 'uninstall', path:, error: e.message.strip)
          failures.push("uninstall #{path}: #{e.message.strip}")
        end
      end
      return failures
    end

    def install
      failures = uninstall
      periods.each do |period|
        index = 900
        entries(period).each do |tool|
          path = dest(period, tool, index)
          index += 1
          # ⚠ 新規構築機には periodic のディレクトリが無いことがある。黙って飛ばさない
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, contents(tool))
          FileUtils.chmod(0o755, path)
          logger.info(action: 'install', path:)
        rescue => e
          logger.error(action: 'install', tool:, error: e.message.strip)
          failures.push("install #{tool}: #{e.message.strip}")
        end
      end
      return failures
    end

    def periods
      return [:hourly, :daily, :weekly, :monthly]
    end

    def entries(period)
      return config["/#{period}"] || []
    end

    def contents(tool)
      return [
        '#!/bin/sh',
        "cd #{Environment.dir}",
        'bundle config silence_root_warning true',
        'bundle install',
        "bin/wb #{tool}",
        '',
      ].join("\n")
    end

    def dest(period, tool, index = 900)
      basename = "#{Package.name}-#{tool}".tr('_', '-')
      case platform
      when :free_bsd, :freebsd
        return File.join(destroot(period), "#{index}.#{basename}.rb")
      when :debian
        return File.join(destroot(period), basename)
      end
      raise unsupported_platform_error
    end

    def destroot(period)
      case platform
      when :free_bsd, :freebsd
        return File.join('/usr/local/etc/periodic', period.to_s)
      when :debian
        return "/etc/cron.#{period}"
      end
      raise unsupported_platform_error
    end

    def platform
      return Environment.platform
    end

    private

    # ⚠ 未対応のプラットフォームでは「0 件インストールして成功」にしない。
    # 従来は dest が nil を返し、`File.write(nil, ...)` の TypeError を
    # エントリごとに握って**全滅しても終了コード 0** だった（#72）。
    def unsupported_platform_error
      return "未対応のプラットフォームです (#{platform.inspect})"
    end
  end
end
