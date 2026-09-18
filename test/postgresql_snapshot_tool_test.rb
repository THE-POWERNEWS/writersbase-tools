module WritersBase
  class PostgresqlSnapshotToolTest < TestCase
    def setup
      @tool = Tool.create('postgresql_snapshot')
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ target に既定を持たせない（#67）。ZFS のデータセット名は環境ごとに違い、
    # 存在しないものを指すと掃除も作成も静かに空振りする。zfs を叩く前に落とす
    def test_execute_without_target
      omit('target が設定されている') if config?('/postgresql_snapshot/target')
      failures = @tool.exec[:failure]

      assert_true(failures.any? {|failure| failure[:error].to_s.include?('target')})
    end

    # ⚠⚠ dsn にも既定を持たせない（#87）。DB 名まで埋まった既定を別のノードへ
    # 写すと、存在しない DB に繋ぎ続ける
    # ⚠ Ginseng::Config#[] は未定義キーで ConfigError を投げる（nil を返さない）。
    # `dsn: null` はキーごと落ちるので、既定が消えたことはこの形で見る
    def test_dsn_without_default
      omit('dsn が設定されている') if config?('/postgresql_snapshot/dsn')

      assert_raise(Ginseng::ConfigError) {@tool.send(:dsn)}
    end

    # ⚠ target の検査が先に当たるので、そちらを通してから dsn の検査だけを見る
    def test_execute_without_dsn
      omit('dsn が設定されている') if config?('/postgresql_snapshot/dsn')
      @tool.define_singleton_method(:target) {'zroot/pg/data'}
      failures = @tool.exec[:failure]

      assert_true(failures.any? {|failure| failure[:error].to_s.include?('dsn')})
    end

    # ⚠ 日時を取り出せない名前は、このツールが作ったものではない。手で退避した
    # スナップショット（`@before-migration` 等）を毎時の掃除で消さないこと（#61）
    def test_obsolete_without_timestamp
      assert_false(@tool.send(:obsolete?, {name: 'zroot/postgres@before-migration', time: nil}))
    end

    def test_obsolete_with_expired_timestamp
      time = Time.now - ((@tool.send(:days) + 1) * 86_400)

      assert_true(@tool.send(:obsolete?, {name: "zroot/postgres@#{time.strftime('%F_%T')}", time:}))
    end

    def test_obsolete_with_fresh_timestamp
      time = Time.now

      assert_false(@tool.send(:obsolete?, {name: "zroot/postgres@#{time.strftime('%F_%T')}", time:}))
    end
  end
end
