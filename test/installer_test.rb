module WritersBase
  class InstallerTest < TestCase
    def setup
      @installer = Installer.instance
    end

    def test_periods
      assert_equal([:hourly, :daily, :weekly, :monthly], @installer.periods)
    end

    # periodic スクリプトの最後の行が bin/wb なので、終了コードはそのまま periodic へ伝わる
    def test_contents
      contents = @installer.contents('postgresql_dump')

      assert_match(%r{\A\#!/bin/sh}, contents)
      assert_match(%r{bin/wb postgresql_dump\n\z}, contents)
    end

    # ⚠⚠ cron から走るスクリプトに依存を入れさせない（#68）。復活させると、毎時
    # root が rubygems.org へ出ていき、レビューを経ていない Gemfile が無人で入る
    def test_contents_does_not_install_gems
      contents = @installer.contents('postgresql_dump')

      assert_not_match(/bundle install/, contents)
      assert_match(/bundle check/, contents)
      assert_match(/未充足/, contents)
    end

    # ⚠ cd の失敗で先へ進ませない。違うディレクトリの bin/wb を叩きうる（#68）
    def test_contents_aborts_on_error
      contents = @installer.contents('postgresql_dump')

      assert_match(/^set -e$/, contents)
      assert_match(%r{^cd '/.+'$}, contents)
    end

    # ⚠ チェックアウトへ .bundle/config を書きに行かせない（#68）
    def test_contents_does_not_write_bundle_config
      contents = @installer.contents('postgresql_dump')

      assert_not_match(/bundle config/, contents)
      assert_match(/BUNDLE_SILENCE_ROOT_WARNING=1/, contents)
    end

    def test_dest
      assert_match(/writersbase-tools-postgresql-dump/, @installer.dest(:daily, 'postgresql_dump'))
    end

    # ⚠⚠ 未対応プラットフォームでは「0 件インストールして成功」にしない。
    # 従来は dest が nil を返し、File.write(nil, ...) の TypeError を握って
    # 全滅しても終了コード 0 だった（#72）
    def test_unsupported_platform
      @installer.define_singleton_method(:platform) {:plan9}

      assert_raise(RuntimeError) {@installer.destroot(:hourly)}
      assert_raise(RuntimeError) {@installer.dest(:hourly, 'postgresql_dump')}
    ensure
      @installer.singleton_class.send(:remove_method, :platform)
    end
  end
end
