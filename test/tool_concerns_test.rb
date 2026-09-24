module WritersBase
  # ⚠⚠ #124 の再発防止。同じ処理を 2 つのツールへ写経すると、#61 / #62 のような
  # 「片方に入れ忘れたら壊れる」修正が片方にしか入らない。寄せた先が本当に使われて
  # いること（ツール側で上書きし直していないこと）を確かめる
  class ToolConcernsTest < TestCase
    CONCERNS = {
      TootctlCommands => {
        'mastodon_maintenance' => [:exec],
        'mastodon_media_cleanup' => [:exec],
      },
      DumpRotation => {
        'mysql_dump' => [:exec, :dump, :delete_old_files, :finder, :dump_path],
        'postgresql_dump' => [:exec, :dump, :delete_old_files, :finder, :dump_path],
      },
      SnapshotRotation => {
        'mysql_snapshot' => [:exec, :snapshots, :clean_snapshots, :obsolete?],
        'postgresql_snapshot' => [:exec, :snapshots, :clean_snapshots, :obsolete?],
      },
    }.freeze

    def test_methods_come_from_concern
      CONCERNS.each do |concern, tools|
        tools.each do |name, methods|
          tool = Tool.create(name)

          methods.each do |method|
            assert_equal(concern, tool.method(method).owner, "#{name}##{method}")
          end
        end
      end
    end

    def test_media_cleanup
      tool = Tool.create('mastodon_media_cleanup')

      assert_kind_of(String, tool.description)
      assert_kind_of(Array, tool.exec[:failure])
    end

    # ⚠ パスワードは環境変数で渡し、コマンドラインに載せない（`ps` から読めるため）
    def test_dump_password_stays_out_of_args
      {'mysql_dump' => 'MYSQL_PWD', 'postgresql_dump' => 'PGPASSWORD'}.each do |name, key|
        tool = Tool.create(name)
        params = {host: 'localhost', user: 'u', password: 'secret-9f3c', port: 5432, db: 'db'}

        assert_not_match(/secret-9f3c/, tool.send(:dump_args, '/tmp/db.sql.zst', params).join(' '))
        assert_equal({key => 'secret-9f3c'}, tool.send(:dump_env, params))
      end
    end
  end
end
