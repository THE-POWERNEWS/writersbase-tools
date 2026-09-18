module WritersBase
  class MysqlDumpTool < Tool
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      databases.each do |db|
        dir = File.join(dest_dir, db)
        FileUtils.mkdir_p(dir)
        path = dump_path(db, dir)
        dump(path, host:, user:, password:, port:, db:)
        result[:success].push(path)
        result[:delete].concat(delete_old_files(dir))
      rescue => e
        logger.error(tool: underscore, db:, error: e.message.strip)
        result[:failure].push(db:, error: e.message.strip)
      end
      return result
    end

    def description
      return 'MySQLのダンプファイルを作成します。'
    end

    private

    def dump(path, params = {})
      logger.info(tool: underscore, db: params[:db], message: 'ダンプ開始')
      return if test?
      execute(pipefail_args(dump_args(path, params)), env: {'MYSQL_PWD' => params[:password]})
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

    # ⚠⚠ **`mysqldump` の既定は `--opt`** で、`--lock-tables` と `--quick` は**既に有効**
    # （実測: `lock-tables TRUE` / `quick TRUE` / `single-transaction FALSE`）。
    # つまり今も 1 つの DB の中では一貫している。⚠ 代わりに**ダンプのあいだ書き込みが止まる**。
    #
    # `--single-transaction` は `--lock-tables` を**自動的に無効にして**、InnoDB の MVCC で
    # 一貫性を取る。書き込みを止めずに済むが、🔴 **MyISAM のテーブルには何の保護も無くなる**
    # ので、混ざっている DB では**いまより悪くなる**（#79）。
    # ⚠ ダンプ中の DDL でも壊れる。
    def dump_args(path, params)
      args = ['mysqldump', '-h', params[:host], '-u', params[:user], '--port', params[:port]]
      args.push('--single-transaction') if single_transaction?
      args.push(params[:db], :|, 'zstd', "-#{config['/zstd/level']}", :>, path)
      return args
    end

    # ⚠ 既定は有効。⚠⚠ **MyISAM を含む DB では false にすること**（`--lock-tables` に戻る）。
    def single_transaction?
      return config["/#{underscore}/single_transaction"] != false
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
