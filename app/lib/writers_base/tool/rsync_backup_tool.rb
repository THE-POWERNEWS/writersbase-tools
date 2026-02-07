module WritersBase
  class RsyncBackupTool < Tool
    def exec(args = {})
      result = {success: [], failure: []}
      sources.each do |src|
        sync(src, result)
      rescue => e
        logger.error(tool: underscore, src:, error: e.message.strip)
        result[:failure].push(src:, error: e.message.strip)
      end
      return result
    end

    def description
      return 'rsyncでファイルを外部サーバーにバックアップします。'
    end

    private

    def sync(src, result)
      remote_path = "#{dest}#{src}"
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期開始')
      command = CommandLine.new([
        'rsync', '-avz', '--delete',
        *excludes.flat_map {|pattern| ['--exclude', pattern]},
        "#{src}/",
        remote_path
      ])
      return if test?
      command.exec
      raise command.stderr unless command.status.zero?
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期完了')
      result[:success].push(src)
    end

    def dest
      return config["/#{underscore}/dest"]
    end

    def excludes
      return config["/#{underscore}/excludes"] || []
    end
  end
end
