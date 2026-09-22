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

module WritersBase
  # ⚠ /var/log/nginx が無い環境でも、対象の絞り込みだけは確かめる（#123）
  class AccessLogCompressToolPatternTest < TestCase
    class LoggerSpy
      attr_reader :errors

      def initialize
        @errors = []
      end

      def info(message)
      end

      def error(message)
        @errors.push(message)
      end
    end

    def setup
      @dir = Dir.mktmpdir
      config['/access_log_compress/dir'] = @dir
      @tool = Tool.create('access_log_compress')
      old = 3.days.ago.to_time
      ['vhost/2026/09/access_20260918.log', 'error/error.log', 'access.log', 'vhost/2026/09/access_20260917.log.zst']
        .each do |name|
          path = File.join(@dir, name)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, 'x')
          File.utime(old, old, path)
        end
    end

    def teardown
      FileUtils.rm_rf(@dir)
      super
    end

    # ⚠⚠ nginx が開いたままの error.log / access.log に当てない。`zstd --rm` で消すと、
    # nginx は削除済みの inode へ書き続けてログが静かに失われる
    def test_finder_matches_only_rotated_logs
      files = @tool.send(:finder).execute.map {|path| path.delete_prefix("#{@dir}/")}

      assert_equal(['vhost/2026/09/access_20260918.log'], files)
    end

    # ⚠ 集約の result: 行が落ちても、どのファイルで失敗したかが残ること（#119 と重なる）
    def test_failure_is_logged_per_file
      spy = LoggerSpy.new
      @tool.instance_variable_set(:@logger, spy)
      @tool.define_singleton_method(:compress) {|_path| raise 'boom'}
      result = @tool.exec

      assert_equal(1, result[:failure].size)
      assert_equal(1, spy.errors.size)
      assert_match(/access_20260918\.log/, spy.errors.first[:file])
    end
  end
end
