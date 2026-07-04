module WritersBase
  class MastodonMaintenanceToolTest < TestCase
    def setup
      @tool = Tool.create('mastodon_maintenance')
    end

    def test_execute
      assert_kind_of(Array, @tool.exec[:success])
      assert_kind_of(Array, @tool.exec[:failure])
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    def test_login_shell
      command = @tool.send(:login_command, ['bundle', 'check'])

      assert_match(/\Abash -lc /, command.to_s)
    end
  end
end
