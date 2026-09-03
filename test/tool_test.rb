module WritersBase
  class ToolTest < TestCase
    def setup
      @tool = Tool.create('help')
    end

    def test_all
      Tool.all do |tool|
        assert_kind_of(Tool, tool)
      end
    end

    # ⚠ Ginseng::CommandLine#exec は status を返すだけで例外を投げない。
    # 落ちたコマンドを success として記録しないよう、Tool#execute で例外にする（#63）
    def test_command_error_uses_stderr
      command = CommandLine.new(['sh', '-c', 'echo boom >&2; exit 3'])
      command.exec

      assert_equal('boom', @tool.send(:command_error, command))
    end

    # ⚠⚠ `sh` はパイプラインの末尾の status しか返さないので、`pg_dump | zstd > path` は
    # pg_dump が落ちても 0 になる。bash の pipefail を明示して拾う（#62）
    def test_pipefail_args
      args = @tool.send(:pipefail_args, ['false', :|, 'zstd', '-3', :>, '/tmp/dump.zst'])

      assert_equal(['bash', '-o', 'pipefail', '-c', 'false | zstd -3 > /tmp/dump.zst'], args)
    end

    # ⚠ zfs destroy のように何も言わずに落ちるコマンドがあるので、stderr が空でも
    # 「どのコマンドがどう落ちたか」は残す。⚠ CommandLine#status は生値（3 なら 768）
    # なので、そのまま出さずに終了コードへ直す
    def test_command_error_without_stderr
      command = CommandLine.new(['sh', '-c', 'exit 3'])
      command.exec

      assert_match(/exit 3/, @tool.send(:command_error, command))
    end
  end
end
