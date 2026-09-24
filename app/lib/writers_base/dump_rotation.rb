module WritersBase
  # DB ごとにダンプを取り、保持期間を過ぎたものを消す（#124）。
  #
  # ⚠⚠ `MysqlDumpTool` / `PostgresqlDumpTool` に写経されていたため、#62（失敗したら
  # 掃除しない）が「片方に入れ忘れたら壊れる」形で 2 か所にあった。ここに 1 つだけ置く。
  #
  # include する側は `dump_args(path, params)` と `dump_env(params)` を持つこと。
  module DumpRotation
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      databases.each do |db|
        dir = File.join(dest_dir, db)
        FileUtils.mkdir_p(dir)
        path = dump_path(db, dir)
        dump(path, host:, user:, password:, port:, db:)
        result[:success].push(path)
        # ⚠⚠ ダンプが落ちたらここへは来ない。**正常なダンプを消さない**（#62）
        result[:delete].concat(delete_old_files(dir))
      rescue => e
        logger.error(tool: underscore, db:, error: e.message.strip)
        result[:failure].push(db:, error: e.message.strip)
      end
      return result
    end

    private

    def dump(path, params = {})
      logger.info(tool: underscore, db: params[:db], message: 'ダンプ開始')
      return if test?
      # ⚠ パスワードは環境変数で渡す。コマンドラインに載せると `ps` から読める
      execute(pipefail_args(dump_args(path, params)), env: dump_env(params))
      verify_archive(path)
      FileUtils.chmod(0o640, path)
      FileUtils.chown('root', root_group, path)
      # ⚠ 以前は ensure に置いていたため、失敗した回にも「ダンプ完了」と出ていた
      logger.info(tool: underscore, db: params[:db], message: 'ダンプ完了')
    rescue
      # ⚠ 壊れた .zst を残さない。zstd は空の入力でも正しいファイルを書くので、
      # 残すと次の回まで「今日のダンプ」に見える
      FileUtils.rm_f(path)
      raise
    end

    def delete_old_files(dir)
      deleted = []
      finder(dir).execute do |f|
        logger.info(tool: underscore, file: f, message: 'ファイル削除')
        File.unlink(f)
        deleted.push(f)
      end
      # ⚠ WritersBase::Logger#warn は error へ転送されるので、正常な状態を error で出さない
      logger.info(tool: underscore, dir:, message: '削除対象ファイルなし') if deleted.empty?
      return deleted
    end

    def finder(dir)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns = ['*.sql.zst', '*.sql.gz']
      finder.mtime = days
      return finder
    end

    def dump_path(db, dir)
      return File.join(dir, "#{db}_#{Time.now.strftime('%Y-%m-%d')}.sql.zst")
    end

    def dest_dir = config["/#{underscore}/dest/dir"]
  end
end
