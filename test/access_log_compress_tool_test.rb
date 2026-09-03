module WritersBase
  class AccessLogCompressToolTest < TestCase
    # ⚠ 対象ディレクトリ（既定 /var/log/nginx）が無い環境では前提を満たさない。
    # 落として赤を常態化させず、omission として数える（ginseng-style の
    # `disable?` パターン。「実行されていない」を緑に埋もれさせないため）
    def disable?
      return true unless File.directory?(config['/access_log_compress/dir'].to_s)
      return super
    end

    def setup
      return if disable?
      @tool = Tool.create('access_log_compress')
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
