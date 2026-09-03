module WritersBase
  class MysqlSnapshotToolTest < TestCase
    def setup
      @tool = Tool.create('mysql_snapshot')
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠ 日時を取り出せない名前は、このツールが作ったものではない。手で退避した
    # スナップショット（`@before-migration` 等）を毎時の掃除で消さないこと（#61）
    def test_obsolete_without_timestamp
      assert_false(@tool.send(:obsolete?, {name: 'zroot/mysql@before-migration', time: nil}))
    end

    def test_obsolete_with_expired_timestamp
      time = Time.now - ((@tool.send(:days) + 1) * 86_400)

      assert_true(@tool.send(:obsolete?, {name: "zroot/mysql@#{time.strftime('%F_%T')}", time:}))
    end

    def test_obsolete_with_fresh_timestamp
      time = Time.now

      assert_false(@tool.send(:obsolete?, {name: "zroot/mysql@#{time.strftime('%F_%T')}", time:}))
    end
  end
end
