module WritersBase
  class MysqlDumpTool < Tool
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      databases.each do |db|
        dir = File.join(dest_dir, db)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{db}_#{Time.now.strftime('%Y-%m-%d')}.sql.gz")
        result[:success].push(dump(path, {host:, user:, password:, port:, db:}))
        finder(dir).execute do |f|
          File.unlink(f)
          result[:delete].push(f)
        end
      rescue => e
        result[:failure].push(path:, error: e.message.strip)
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
        '--single-transaction',
        '--skip-dump-date',
        :|, 'gzip'
        :>, Shellwords.escape(path)
      ])
      command.env = {'MYSQL_PWD' => params[:password]}
      return if Environment.test?
      command.exec
      FileUtils.chmod(0o640, path)
      FileUtils.chown('root', 'adm', path)
      return path
    end

    def finder(dir)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns = ['*.log']
      finder.patterns = ['*.sql.gz']
      finder.mtime = days
      return finder
    end

    def dest_dir
      config["/#{underscore}/dest/dir"]
    end
  end
end
