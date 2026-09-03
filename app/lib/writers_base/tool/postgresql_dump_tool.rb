module WritersBase
  class PostgresqlDumpTool < Tool
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
      return 'PostgreSQLのダンプファイルを作成します。'
    end

    private

    def dump(path, params = {})
      logger.info(tool: underscore, db: params[:db], message: 'ダンプ開始')
      return if test?
      execute(pipefail_args([
        'nice', '-n', '19',
        'pg_dump',
        '-h', params[:host],
        '-U', params[:user],
        '-p', params[:port],
        '-d', params[:db],
        :|, 'nice', '-n', '19',
        'zstd', "-#{config['/zstd/level']}",
        :>, path
      ]), env: {'PGPASSWORD' => params[:password]})
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
