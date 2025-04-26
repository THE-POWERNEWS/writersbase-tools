module WritersBase
  class PostgresqlDumpTool < Tool
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      databases.each do |db|
        begin
          dir = File.join(dest_dir, db)
          FileUtils.mkdir_p(dir)
          path = dump_path(db, dir)

          logger.info(tool: underscore, db:, message: 'ダンプ開始')
          dump(path, host:, user:, password:, port:, db:)
          logger.info(tool: underscore, db:, path:, message: 'ダンプ完了')
          result[:success] << path

          finder(dir).execute do |f|
            logger.info(tool: underscore, file: f, message: 'ファイル削除')
            File.unlink(f)
            result[:delete] << f
          end
        rescue => e
          logger.error(tool: underscore, db:, error: e.message.strip, class: e.class.to_s)
          result[:failure] << {db:, error: e.message.strip, class: e.class.to_s}
        end
      end
      return result
    end

    def description
      return 'PostgreSQLのダンプファイルを作成します。'
    end

    private

    def dump(path, params = {})
      command = Ginseng::CommandLine.new([
        'pg_dump',
        '-h', params[:host],
        '-U', params[:user],
        '-p', params[:port],
        '-d', params[:db],
        :|, 'gzip',
        :>, path
      ])
      command.env = {'PGPASSWORD' => params[:password]}
      return if test_mode?
      command.exec
      FileUtils.chmod(0o640, path)
      FileUtils.chown('root', 'adm', path)
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

    def test_mode?
      return Environment.test?
    end

    def dest_dir
      config["/#{underscore}/dest/dir"]
    end
  end
end
