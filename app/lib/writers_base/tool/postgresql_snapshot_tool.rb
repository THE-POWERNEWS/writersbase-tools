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
            timestamp = name.match(/\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}/)
            time = Time.parse(timestamp[0].tr('_', ' ')) rescue nil
            {name:, time:}
          end
    end

    def clean_snapshots(result)
      snapshots.each do |snapshot|
        next unless obsolete?(snapshot)
        logger.info(tool: underscore, snapshot: snapshot[:name], message: 'スナップショット削除')
        CommandLine.new(['zfs', 'destroy', snapshot[:name]]).exec unless test?
        result[:delete].push(snapshot[:name])
      end
    end

    # ⚠ 日時を取り出せない名前は、このツールの持ち物ではない（作るものは必ず %F_%T を持つ）。
    # 手で退避したスナップショット（`@before-migration` 等）を消さないよう、掃除の対象から外す。
    def obsolete?(snapshot)
      return false unless snapshot[:time]
      return snapshot[:time] < Time.now - (days * 86_400)
    end

    def create_snapshot(result)
      name = "#{target}@#{Time.now.strftime('%F_%T')}"
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成開始')

      pg = PG::Connection.new(dsn)
      pg.exec_params(%{SELECT * FROM pg_backup_start($1, false)}, [name])
      CommandLine.new(['zfs', 'snapshot', name]).exec unless test?
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成完了')
      pg.exec(%{SELECT * FROM pg_backup_stop(true)})

      result[:success].push(name)
    ensure
      pg&.close
    end

    def target = config["/#{underscore}/target"]
    def dsn = config["/#{underscore}/dsn"]
  end
end
