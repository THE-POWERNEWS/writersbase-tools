module WritersBase
  class TestCase < Ginseng::TestCase
    include Package

    def teardown
      config.reload
    end
  end
end
