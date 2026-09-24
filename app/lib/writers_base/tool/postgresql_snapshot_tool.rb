module WritersBase
  class PostgresqlSnapshotTool < Tool
    include SnapshotRotation

    def description
      return 'PostgreSQLのZFSスナップショットを作成・管理します。'
    end

    private

    # ⚠⚠ dsn にも既定を持たせない（#87）。以前の既定は DB 名まで埋まっていたため、
    # Mastodon 以外のノードへ写すと**存在しない DB に繋ぎ続ける**。
    def validate_config!
      super
      raise Ginseng::ConfigError, "'/#{underscore}/dsn' not found" if dsn.blank?
    end

    def create_snapshot(result)
      name = snapshot_name
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成開始')

      pg = PG::Connection.new(dsn)
      pg.exec_params(%{SELECT * FROM pg_backup_start($1, false)}, [name])
      execute(['zfs', 'snapshot', name])
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成完了')
      pg.exec(%{SELECT * FROM pg_backup_stop(true)})

      result[:success].push(name)
    ensure
      # ⚠ zfs が落ちて pg_backup_stop まで進めなくても、接続を閉じれば
      # 非排他バックアップは中断される
      pg&.close
    end

    def dsn = config["/#{underscore}/dsn"]
  end
end
