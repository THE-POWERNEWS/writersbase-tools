module WritersBase
  class Installer
    include Singleton
    attr_reader :logger, :config

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    def uninstall
      periods.each do |period|
        Dir.glob(File.join(destroot(period), '*')) do |path|
          next unless File.basename(path).include?(Package.name)
          File.unlink(path)
          logger.info(action: 'uninstall', path:)
        rescue => e
          logger.error(error: e)
        end
      end
    end

    def install
      periods.each do |period|
        entries(period).each do |tool|
          path = dest(period, tool)
          File.write(path, contents(tool))
          FileUtils.chmod(0o755, path)
          logger.info(action: 'install', path:)
        rescue => e
          logger.error(error: e)
        end
      end
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
        "bin/wb.rb #{tool}",
        '',
      ].join("\n")
    end

    def dest(period, tool)
      case Environment.platform
      when 'FreeBSD'
        return File.join(destroot(period), "900.#{Package.name}-#{tool}.rb")
      when 'Debian'
        return File.join(destroot(period), "#{Package.name}-#{tool}.rb")
      end
    end

    def destroot(period)
      case Environment.platform
      when 'FreeBSD'
        return File.join('/usr/local/etc/periodic', period)
      when 'Debian'
        return "/etc/cron.#{period}"
      end
    end
  end
end
