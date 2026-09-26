module WritersBase
  class WordpressOutdatedToolTest < TestCase
    OFFERS = ['7.1.2', '7.1.2', '7.0.6', '6.9.9'].map {|v| Gem::Version.new(v)}.freeze

    def setup
      @tool = Tool.create('wordpress_outdated')
      @dir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(@dir, 'wp-includes'))
      @tool.define_singleton_method(:latest_versions) {OFFERS}
    end

    def teardown
      FileUtils.rm_rf(@dir)
    end

    def install(version)
      File.write(File.join(@dir, 'wp-includes/version.php'), "<?php\n$wp_version = '#{version}';\n")
      config['/wordpress_outdated/dirs'] = [@dir]
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # WordPress の無いノードでは API も引かずに黙って終わる
    def test_without_dirs
      config['/wordpress_outdated/dirs'] = []
      @tool.define_singleton_method(:latest_versions) {raise 'API を引いてはいけない'}

      assert_equal('', @tool.exec)
      assert_nil(@tool.alert)
    end

    def test_up_to_date
      install('7.1.2')

      assert_equal('', @tool.exec)
      assert_nil(@tool.alert)
    end

    # 🔴 自動更新が当たっていなければ heartbeat を down にする（#141 の口）
    def test_outdated
      install('7.1.1')

      assert_equal("WordPress が古い（#{@dir}: 導入 7.1.1 / 最新 7.1.2）", @tool.exec)
      assert_equal("WordPress が古い（#{@dir}: 導入 7.1.1 / 最新 7.1.2）", @tool.alert)
      assert_false(@tool.failed?)
    end

    # 比べるのは同じブランチの最新。7.0 系の最新なら、7.1 が出ていても古くない
    def test_older_branch_up_to_date
      install('7.0.6')

      assert_equal('', @tool.exec)
    end

    def test_older_branch_outdated
      install('7.0.5')

      assert_match(/最新 7\.0\.6/, @tool.exec)
    end

    # ⚠⚠ 読めなければ「最新」へ倒さない（#63 / #122 と同じ型）
    def test_missing_version_file
      config['/wordpress_outdated/dirs'] = [@dir]

      assert_raise(RuntimeError) {@tool.exec}
    end

    def test_unreadable_version
      File.write(File.join(@dir, 'wp-includes/version.php'), "<?php\n")
      config['/wordpress_outdated/dirs'] = [@dir]

      assert_raise(RuntimeError) {@tool.exec}
    end

    # ⚠ ブランチの提供が API に無ければ判定できない。黙らず例外にする
    def test_branch_not_offered
      install('5.0.1')

      assert_raise(RuntimeError) {@tool.exec}
    end
  end
end
