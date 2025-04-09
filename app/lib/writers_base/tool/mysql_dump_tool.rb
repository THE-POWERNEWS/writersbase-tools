module WritersBase
  class MySQLDumpTool < Tool
    def exec(args = {})
      databases.each do |db|
        dir = File.join(dest_dir, db)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "#{db}_#{Time.now.strftime('%Y-%m-%d')}.sql")
        dump(path, {host:, user:, password:, port:, db:})
        finder(dir).execute do |f|
          File.unlink(f)
        end
      end
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
        '-p', params[:port],
        '-r', path,
        params[:db],
        '--single-transaction',
        '--skip-dump-date'
      ])
      command.env = {'MYSQL_PWD' => params[:password]}
      return if Environment.test?
      command.exec
      compress(path)
      File.chmod(0o640, dest)
    end

    def finder(dir)
      finder = Ginseng::FileFinder.new
      finder.dir = dir
      finder.patterns = ['*.log']
      finder.patterns = ['*.sql.gz']
      finder.mtime = days
      return @finder
    end

    def dest_dir
      config["/#{underscore}/dest/dir"]
    end
  end
end
