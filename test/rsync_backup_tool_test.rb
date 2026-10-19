module WritersBase
  class RsyncBackupToolTest < TestCase
    DEST = 'rsync@seas.example:~/backup/node'.freeze

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

    # ⚠ 文字列の書き方は従来どおり、送り元の絶対パスがそのまま生える（#188）
    def test_string_source
      config['/rsync_backup/dest'] = DEST
      config['/rsync_backup/sources'] = ['/etc', '/usr/local/etc']
      paths = @tool.entries.map {|entry| @tool.remote_path(entry)}

      assert_equal(["#{DEST}/etc", "#{DEST}/usr/local/etc"], paths)
    end

    # 旧 ginseng の `dest:` に当たる名前を付けられる（#188）
    def test_named_source
      config['/rsync_backup/dest'] = DEST
      config['/rsync_backup/sources'] = ['/etc', {'src' => '/var/movies', 'name' => 'movies'}]
      entry = @tool.entries.last

      assert_equal({src: '/var/movies', name: 'movies'}, entry)
      assert_equal("#{DEST}/movies", @tool.remote_path(entry))
      assert_equal(['/var/movies/', "#{DEST}/movies"], @tool.rsync_args(entry).last(2))
    end

    def test_nested_name
      config['/rsync_backup/dest'] = DEST
      config['/rsync_backup/sources'] = [{'src' => '/home/pooza/EPGStation/config', 'name' => 'epgstation/config'}]

      assert_equal("#{DEST}/epgstation/config", @tool.remote_path(@tool.entries.first))
    end

    def test_default_sources_do_not_overlap
      config['/rsync_backup/dest'] = DEST

      assert_nothing_raised {@tool.entries}
    end

    def test_invalid_name
      ['', '/movies', '../movies', 'a/../b', 'a//b', '.', 'movies/', 'movies//'].each do |name|
        config['/rsync_backup/sources'] = [{'src' => '/var/movies', 'name' => name}]

        assert_raise(Ginseng::ConfigError, name) {@tool.entries}
      end
    end

    def test_src_undefined
      config['/rsync_backup/sources'] = [{'name' => 'movies'}]

      assert_raise(Ginseng::ConfigError) {@tool.entries}
    end

    # ⚠⚠ 空の要素を `''` に丸めると、送り元が `/`・送り先が dest の直下になる（Codex P1）
    def test_invalid_source
      [nil, '', '  ', 123, ['/etc'], {'src' => nil, 'name' => 'x'}, {'src' => '', 'name' => 'x'}].each do |source|
        config['/rsync_backup/sources'] = [source]

        assert_raise(Ginseng::ConfigError, source.inspect) {@tool.entries}
      end
    end

    # ⚠ 旧 ginseng の `dest:` をそのまま写したものは黙って通さない
    def test_unknown_key
      config['/rsync_backup/sources'] = [{'src' => '/usr/local/etc/', 'dest' => 'local.etc'}]

      assert_raise(Ginseng::ConfigError) {@tool.entries}
    end

    # ⚠⚠ `--delete` が互いの中身を消し合うので、送り先が重なる設定は 1 件も送らない
    def test_overlapping_destinations
      [
        ['/etc', {'src' => '/usr/local/etc', 'name' => 'etc'}],
        [{'src' => '/a', 'name' => 'backup'}, {'src' => '/b', 'name' => 'backup/sub'}],
        ['/usr/local', '/usr/local/etc'],
        ['/', '/etc'],
      ].each do |sources|
        config['/rsync_backup/sources'] = sources

        assert_raise(Ginseng::ConfigError, sources.inspect) {@tool.entries}
      end
    end

    def test_similar_names_do_not_overlap
      config['/rsync_backup/sources'] = [{'src' => '/a', 'name' => 'etc'}, {'src' => '/b', 'name' => 'etc2'}]

      assert_nothing_raised {@tool.entries}
    end

    def test_exec
      config['/rsync_backup/dest'] = DEST
      config['/rsync_backup/sources'] = ['/etc', {'src' => '/var/movies', 'name' => 'movies'}]
      result = @tool.exec

      assert_equal(['/etc', '/var/movies'], result[:success])
      assert_empty(result[:failure])
    end

    def test_exec_with_overlap
      config['/rsync_backup/dest'] = DEST
      config['/rsync_backup/sources'] = ['/etc', {'src' => '/usr/local/etc', 'name' => 'etc'}]

      assert_raise(Ginseng::ConfigError) {@tool.exec}
    end
  end
end
