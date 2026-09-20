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

    # ⚠⚠ キーごと消えても有効側へ倒す（#104）。`config[...] != false` のままだと、
    # ここは例外になっていた ＝ **「無ければ既定」は効いていなかった**
    def test_links_enabled_without_key
      config.delete('/google_drive_backup/links')

      assert_true(@tool.send(:links?))
    end

    # ⚠ excludes も同じ。`|| []` は例外の前に到達しない（#104）
    def test_excludes_without_key
      config.delete('/google_drive_backup/excludes')

      assert_equal([], @tool.send(:excludes))
    end

    # ⚠⚠ `rclone sync` は宛先を source に合わせるので、**宛先が定まらないまま
    # 走らせない**（#120）。🔴 既定が `/backup` だったころは、path を書き忘れた
    # 2 台目が 1 台目と同じ `gdrive:/backup/etc` へ sync して、先に置かれていた
    # ぶんを消していた。
    def test_execute_without_path
      omit('path が設定されている') if config?('/google_drive_backup/path')

      assert_raise(Ginseng::ConfigError) {@tool.exec}
    end

    # ⚠ `path: ''` のような空値も、キーが無いのと同じ形で落ちること
    def test_execute_with_blank_path
      config['/google_drive_backup/path'] = ''

      assert_raise(Ginseng::ConfigError) {@tool.exec}
    end

    # ⚠ remote も同じ扱い。⚠⚠ **既定を持つ側だが、空にされたら落とす**
    def test_execute_with_blank_remote
      config['/google_drive_backup/path'] = '/backup/example.jp'
      config['/google_drive_backup/remote'] = ''

      assert_raise(Ginseng::ConfigError) {@tool.exec}
    end
  end
end
