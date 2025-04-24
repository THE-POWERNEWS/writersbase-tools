module WritersBase
  class PostgresqlDumpToolTest < TestCase
    def setup
      @tool = Tool.create('postgresql_dump')
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
