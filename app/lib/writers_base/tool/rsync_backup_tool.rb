module WritersBase
  class RsyncBackupTool < Tool
    def exec(args = {})
      result = {success: [], failure: []}
      # ⚠⚠ `rsync --delete` を使う道具なので、宛先が無いまま走らせない。
      # ⚠ ソースごとの失敗にはせず、設定の誤りとして 1 件で落とす（#67）
      raise Ginseng::ConfigError, "'/#{underscore}/dest' not found" if dest.blank?
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
      host, path = dest.split(':', 2)
      remote_path = "#{host}:#{File.join(path, src)}"
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期開始')
      args = [
        'rsync', '-avz', '--delete', '--mkpath',
        *excludes.flat_map {|pattern| ['--exclude', pattern]},
        "#{src}/",
        remote_path
      ]
      execute(args)
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期完了')
      result[:success].push(src)
    end

    def dest = config["/#{underscore}/dest"]
    def excludes = config["/#{underscore}/excludes"] || []
  end
end
