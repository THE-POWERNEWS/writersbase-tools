module WritersBase
  class MysqlSnapshotTool < Tool
    include SnapshotRotation

    def description
      return 'MySQLのZFSスナップショットを作成・管理します。'
    end

    private

    def create_snapshot(result)
      name = snapshot_name
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成開始')

      client = Mysql2::Client.new(host:, username: user, password:, port:)
      client.query('LOCK INSTANCE FOR BACKUP')
      execute(['zfs', 'snapshot', name])
      logger.info(tool: underscore, snapshot: name, message: 'スナップショット作成完了')
      client.query('UNLOCK INSTANCE')

      result[:success].push(name)
    ensure
      # ⚠ zfs が落ちて UNLOCK INSTANCE まで進めなくても、接続を閉じればロックは外れる
      client&.close
    end

    def user = config["/#{underscore}/user"]
  end
end
