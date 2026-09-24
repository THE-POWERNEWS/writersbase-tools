module WritersBase
  class PostgresqlDumpTool < Tool
    include DumpRotation

    def description
      return 'PostgreSQLのダンプファイルを作成します。'
    end

    private

    def dump_args(path, params)
      return [
        'nice', '-n', '19',
        'pg_dump',
        '-h', params[:host],
        '-U', params[:user],
        '-p', params[:port],
        '-d', params[:db],
        :|, 'nice', '-n', '19',
        'zstd', "-#{config['/zstd/level']}",
        :>, path
      ]
    end

    def dump_env(params)
      return {'PGPASSWORD' => params[:password]}
    end
  end
end
