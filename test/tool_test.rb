module WritersBase
  class ToolTest < TestCase
    def test_all
      Tool.all do |tool|
        assert_kind_of(Tool, tool)
      end
    end
  end
end
