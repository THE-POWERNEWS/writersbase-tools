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
  end
end
