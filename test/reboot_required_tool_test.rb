module WritersBase
  class RebootRequiredToolTest < TestCase
    def setup
      @tool = Tool.create('reboot_required')
    end

    def test_exec
      assert_include(['', '再起動が必要'], @tool.exec)
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠⚠ 未対応のプラットフォームで「再起動は不要」と答えない（#122）。
    # #63 で塞いだ「uname が落ちると常に不要へ倒れる」と同じ型
    def test_unsupported_platform
      @tool.define_singleton_method(:platform_family) {Environment.platform_family(:plan9)}

      assert_raise(RuntimeError) {@tool.exec}
    end
  end
end
