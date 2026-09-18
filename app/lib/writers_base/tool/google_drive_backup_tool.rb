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
      execute(sync_args(src, remote_path))
      logger.info(tool: underscore, src:, dest: remote_path, message: '同期完了')
      result[:success].push(src)
    end

    # ⚠⚠ `--links` を渡さない rclone は、シンボリックリンクを**バックアップから落とす**（#97）。
    # 🔴 **しかも exit 0 で終わる。**`NOTICE: ... Can't follow symlink without -L/--copy-links`
    # を出すだけなので、`Tool#execute` は成功として通す。**誰にも気づかれない。**
    # 実測（2026-09-18・同じ入力で 1 リンク）:
    #   - rclone 1.60.1（vulcan / dev27）… NOTICE・**exit 0**・宛先にリンクが無い
    #   - rclone 1.75.1（FreeBSD 3 台）  … NOTICE・**exit 0**・同じ
    # ⚠ 版による違いは無い。⚠⚠ **`WRITERSBASE-TOOLS-4` の非ゼロ終了は symlink ではなく、
    # Drive API のクォータ（403 rateLimitExceeded / pooza/chubo2#193）が原因。**
    # ⚠ `--links` はリンクを `<名前>.rclonelink` というテキストとして保存し、復元でリンクに戻す。
    # `--copy-links` はリンク先の中身を実体として写すので、復元するとリンクが実体に化ける。
    def sync_args(src, remote_path)
      args = ['rclone', 'sync', '--verbose']
      args.push('--links') if links?
      args.concat(exclude_args)
      args.push("#{src}/", remote_path)
      return args
    end

    # ⚠ ディレクトリそのものと配下の両方を渡す（片方だけだと素通りする）。
    def exclude_args
      return excludes.flat_map {|pattern| ['--exclude', "#{pattern}/**", '--exclude', pattern]}
    end

    # ⚠ 既定は有効。⚠⚠ 無効にすると**リンクが黙って落ちる**ので、
    # 宛先に `.rclonelink` を生やせない事情があるときだけ false にすること。
    def links?
      return config.lookup("/#{underscore}/links", true) != false
    end

    def remote = config["/#{underscore}/remote"]
    def path = config["/#{underscore}/path"]
    def excludes = config.lookup("/#{underscore}/excludes", [])
  end
end
