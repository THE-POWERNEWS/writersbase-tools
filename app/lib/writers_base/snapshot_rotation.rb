module WritersBase
  # ZFS スナップショットを作り、保持期間を過ぎたものを消す（#124）。
  #
  # ⚠⚠ `MysqlSnapshotTool` / `PostgresqlSnapshotTool` に写経されていたため、#61（日時を
  # 持たない名前を消さない）の `obsolete?` が 2 か所にあった。ここに 1 つだけ置く。
  #
  # include する側は `create_snapshot(result)` を持つこと。設定の検査を足すときは
  # `validate_config!` を上書きして `super` を呼ぶ。
  module SnapshotRotation
    def exec(args = {})
      result = {success: [], delete: [], failure: []}
      validate_config!
      clean_snapshots(result)
      create_snapshot(result)
      return result
    rescue => e
      logger.error(tool: underscore, error: e.message.strip)
      result[:failure].push(error: e.message.strip)
      return result
    end

    private

    # ⚠ 設定を先に読んで落とす。zfs を叩く前に「設定が無い」と分かるように（#67）
    # ⚠⚠ **ここは Config#lookup を通さない**（#104）。既定へ倒すと、存在しない
    # データセットを黙って掃除しにいく。キーが無ければ target 自身が ConfigError を
    # 投げ、`target: ''` のような空値はこの blank? が拾う。**どちらも同じ形で落ちる。**
    def validate_config!
      raise Ginseng::ConfigError, "'/#{underscore}/target' not found" if target.blank?
    end

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

    def snapshot_name
      return "#{target}@#{Time.now.strftime('%F_%T')}"
    end

    def target = config["/#{underscore}/target"]
  end
end
