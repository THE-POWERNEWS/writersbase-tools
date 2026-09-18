module WritersBase
  class MysqlDumpToolTest < TestCase
    def setup
      @tool = Tool.create('mysql_dump')
    end

    def test_execute
      assert_kind_of(Array, @tool.exec[:success])
      assert_kind_of(Array, @tool.exec[:failure])
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ これが落ちると InnoDB の一貫性が MVCC ではなく `--lock-tables` 任せに戻り、
    # ダンプのあいだ書き込みが止まる（#79）
    def test_dump_args_passes_single_transaction
      args = @tool.send(:dump_args, '/var/backups/db/wp/wp.sql.zst', params)

      assert_include(args, '--single-transaction')
      assert_equal('mysqldump', args.first)
    end

    # ⚠ DB 名は接続オプションの後、パイプの前に置く（順番が崩れると別物を落とす）
    def test_dump_args_keeps_order
      args = @tool.send(:dump_args, '/var/backups/db/wp/wp.sql.zst', params)

      assert_equal('wp', args[args.index(:|) - 1])
      assert_equal([:>, '/var/backups/db/wp/wp.sql.zst'], args.last(2))
    end

    # ⚠ 既定が黙って反転すると、MyISAM の無い DB で書き込みが止まりはじめる
    def test_single_transaction_enabled_by_default
      assert_true(@tool.send(:single_transaction?))
    end

    private

    def params
      return {host: '127.0.0.1', user: 'root', port: 3306, db: 'wp', password: 'secret'}
    end
  end
end
