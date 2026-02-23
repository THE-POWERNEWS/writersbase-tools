module WritersBase
  class GoogleDriveBackupTool < Tool
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
      return 'rcloneでファイルをGoogle Driveにバックアップします。'
    end

    private

    def sync(src, result)
      remote_path = "#{remote}:#{File.join(path, src)}"
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期開始')
      command = CommandLine.new([
        'rclone', 'sync', '--verbose',
        *excludes.flat_map {|pattern| ['--exclude', "#{pattern}/**", '--exclude', pattern]},
        "#{src}/",
        remote_path
      ])
      return if test?
      command.exec
      raise command.stderr unless command.status.zero?
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期完了')
      result[:success].push(src)
    end

    def remote = config["/#{underscore}/remote"]
    def path = config["/#{underscore}/path"]
    def excludes = config["/#{underscore}/excludes"] || []
  end
end
