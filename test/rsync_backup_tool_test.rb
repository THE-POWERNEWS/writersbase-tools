module WritersBase
  class RsyncBackupToolTest < TestCase
    def setup
      @tool = Tool.create('rsync_backup')
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ `rsync --delete` を使う道具なので、それらしいダミーの既定を置かない（#67）。
    # ⚠ ソースごとの失敗ではなく、設定の誤りとして落とす
    def test_execute_without_dest
      omit('dest が設定されている') if config?('/rsync_backup/dest')

      assert_raise(Ginseng::ConfigError) {@tool.exec}
    end
  end
end
