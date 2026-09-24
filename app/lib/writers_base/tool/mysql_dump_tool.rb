module WritersBase
  class MysqlDumpTool < Tool
    include DumpRotation

    def description
      return 'MySQLのダンプファイルを作成します。'
    end

    private

    # ⚠⚠ **`mysqldump` の既定は `--opt`** で、`--lock-tables` と `--quick` は**既に有効**
    # （実測: `lock-tables TRUE` / `quick TRUE` / `single-transaction FALSE`）。
    # つまり今も 1 つの DB の中では一貫している。⚠ 代わりに**ダンプのあいだ書き込みが止まる**。
    #
    # `--single-transaction` は `--lock-tables` を**自動的に無効にして**、InnoDB の MVCC で
    # 一貫性を取る。書き込みを止めずに済むが、🔴 **MyISAM のテーブルには何の保護も無くなる**
    # ので、混ざっている DB では**いまより悪くなる**（#79）。
    # ⚠ ダンプ中の DDL でも壊れる。
    def dump_args(path, params)
      args = ['mysqldump', '-h', params[:host], '-u', params[:user], '--port', params[:port]]
      args.push('--single-transaction') if single_transaction?
      args.push(params[:db], :|, 'zstd', "-#{config['/zstd/level']}", :>, path)
      return args
    end

    # ⚠ 既定は有効。⚠⚠ **MyISAM を含む DB では false にすること**（`--lock-tables` に戻る）。
    def single_transaction?
      return config.lookup("/#{underscore}/single_transaction", true) != false
    end

    def dump_env(params)
      return {'MYSQL_PWD' => params[:password]}
    end
  end
end
