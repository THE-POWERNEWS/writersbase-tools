module WritersBase
  class MysqlSnapshotTool < Tool
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
      return 'MySQLのZFSスナップショットを作成・管理します。'
    end

    private

    def snapshots
      # ⚠ zfs が無い／失敗した環境で「スナップショット 0 件」と読まないよう、
      # バッククォートをやめて終了ステータスを見る（#63）。
      return execute(['zfs', 'list', '-t', 'snapshot']).stdout.to_s
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
        execute(['zfs', 'destroy', snapshot[:name]])
        result[:delete].push(snapshot[:name])
      rescue => e
        # ⚠ 1 枚消せなくても掃除を続け、スナップショットの作成まで進む
        # （`zfs hold` で守られたものが 1 枚あるだけで毎時の作成を止めない）
        logger.error(tool: underscore, snapshot: snapshot[:name], error: e.message.strip)
        result[:failure].push(snapshot: snapshot[:name], error: e.message.strip)
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

    def target = config["/#{underscore}/target"]
    def user = config["/#{underscore}/user"]
  end
end
