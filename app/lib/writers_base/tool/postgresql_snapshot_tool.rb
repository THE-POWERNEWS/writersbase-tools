module WritersBase
  class PostgresqlSnapshotTool < Tool
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      clean_snapshots(result)
      create_snapshot(result)
      return result
    rescue => e
      logger.error(tool: underscore, error: e.message.strip)
      result[:failure].push(error: e.message.strip)
      return result
    end

    def description
      return 'PostgreSQLのZFSスナップショットを作成・管理します。'
    end

    private

    def snapshots
      return `zfs list -t snapshot`
          .each_line
          .map {|line| line.split(/\s+/).first}
          .select {|v| v.split('@').first == target}
          .map do |name|
            date = Date.parse(name.match(/[0-9]{4}-[0-9]{2}-[0-9]{2}/)[0]) rescue nil
            {name:, date:}
          end
    end

    def clean_snapshots(result)
      snapshots.each do |snapshot|
        next unless snapshot[:date].nil? || snapshot[:date] < Date.today - days
        logger.info(tool: underscore, snapshot: snapshot[:name], message: 'スナップショット削除')
        system "zfs destroy #{snapshot[:name]}" unless test?
        result[:delete].push(snapshot[:name])
      end
    end

    def create_snapshot(result)
      name = "#{target}@#{Time.now.strftime('%F_%T')}"
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成開始')

      pg = PG::Connection.new(dsn)
      pg.exec_params(%{SELECT * FROM pg_backup_start($1, false)}, [name])
      system "zfs snapshot #{name}" unless test?
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成完了')
      pg.exec(%{SELECT * FROM pg_backup_stop(true)})

      result[:success].push(name)
    ensure
      pg&.close
    end

    def target
      return config["/#{underscore}/target"]
    end

    def dsn
      return config["/#{underscore}/dsn"]
    end
  end
end
