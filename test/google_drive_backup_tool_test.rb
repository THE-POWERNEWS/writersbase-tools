module WritersBase
  class GoogleDriveBackupToolTest < TestCase
    def setup
      @tool = Tool.create('google_drive_backup')
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ `--links` が落ちると、シンボリックリンクがバックアップから消える。
    # rclone 1.75 は黙って飛ばすので、**落ちたことが誰にも見えない**（#97）
    def test_sync_args_passes_links
      args = @tool.send(:sync_args, '/etc', 'gdrive:/backup/etc')

      assert_include(args, '--links')
      assert_equal(['rclone', 'sync'], args.first(2))
      assert_equal(['/etc/', 'gdrive:/backup/etc'], args.last(2))
    end

    # ⚠ 除外はディレクトリと配下の両方を渡す（片方だけだと素通りする）
    def test_sync_args_passes_excludes
      pairs = @tool.send(:sync_args, '/etc', 'gdrive:/backup/etc').each_cons(2).to_a

      assert_include(pairs, ['--exclude', 'node_modules'])
      assert_include(pairs, ['--exclude', 'node_modules/**'])
    end

    # ⚠ 既定が有効であること自体を固定する。既定が黙って反転すると、
    # 次の sync が宛先の .rclonelink を消しにいく
    def test_links_enabled_by_default
      assert_true(@tool.send(:links?))
    end
  end
end
