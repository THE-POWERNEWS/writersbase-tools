module WritersBase
  class EnvironmentTest < TestCase
    def test_platform_family
      assert_equal(:freebsd, Environment.platform_family(:free_bsd))
      assert_equal(:freebsd, Environment.platform_family(:freebsd))
      assert_equal(:debian, Environment.platform_family(:debian))
    end

    # ⚠⚠ 未対応のプラットフォームで nil を返すと、呼び出し側の case が黙って倒れる（#122）
    def test_platform_family_unsupported
      assert_raise(RuntimeError) {Environment.platform_family(:plan9)}
    end

    # 手元・CI・フリートのいずれも対応プラットフォームで走っている
    def test_platform_family_current
      assert_include([:freebsd, :debian], Environment.platform_family)
    end
  end
end
