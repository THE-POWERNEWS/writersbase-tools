module WritersBase
  class MysqlDumpTool < Tool
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      databases.each do |db|
        dir = File.join(dest_dir, db)
        FileUtils.mkdir_p(dir)
        path = dump_path(db, dir)

        logger.info(tool: underscore, db:, message: 'ダンプ開始')
        dump(path, host:, user:, password:, port:, db:)
        logger.info(tool: underscore, db:, path:, message: 'ダンプ完了')
        result[:success] << path
        result[:delete].concat(delete_old_files(dir))
      rescue => e
        logger.error(tool: underscore, db:, error: e.message.strip, class: e.class.to_s)
        result[:failure] << {db:, error: e.message.strip, class: e.class.to_s}
      end
      return result
    end

    def description
      return 'MySQLのダンプファイルを作成します。'
    end

    private

    def dump(path, params = {})
      command = Ginseng::CommandLine.new([
        'mysqldump',
        '-h', params[:host],
        '-u', params[:user],
        '--port', params[:port],
        params[:db],
        :|, 'gzip',
        :>, path
      ])
      command.env = {'MYSQL_PWD' => params[:password]}
      return if test_mode?
      command.exec
      FileUtils.chmod(0o640, path)
      FileUtils.chown('root', 'adm', path)
    end

    def delete_old_files(dir)
      deleted = []
      finder(dir).execute do |f|
        logger.info(tool: underscore, file: f, message: 'ファイル削除')
        File.unlink(f)
        deleted << f
      end
      logger.warn(tool: underscore, dir:, message: '削除対象ファイルなし') if deleted.empty?
      deleted
    end

    def finder(dir)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns = ['*.sql.gz']
      finder.mtime = days
      return finder
    end

    def dump_path(db, dir)
      return File.join(dir, "#{db}_#{Time.now.strftime('%Y-%m-%d')}.sql.gz")
    end

    def dest_dir
      config["/#{underscore}/dest/dir"]
    end
  end
end
