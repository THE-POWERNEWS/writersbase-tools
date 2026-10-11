require 'tmpdir'

module WritersBase
  class HeartbeatFallbackTest < TestCase
    def setup
      @root = Dir.mktmpdir
      @dirs = ['config', 'usr-local-etc', 'etc'].map {|name| File.join(@root, name)}
      @dirs.each {|dir| FileUtils.mkdir_p(dir)}
    end

    def teardown
      FileUtils.rm_rf(@root)
      super
    end

    # ⚠⚠ 設定の読み方は Ginseng::Config#load の写し。本体が置き場や順序を変えたら
    # ここで気づく（黙ってずれると、本体は送れるのに fallback だけ送れない）
    def test_search_order_matches_config
      fallback = HeartbeatFallback.new('postgresql_dump')

      assert_equal(config.dirs, fallback.default_dirs)
      assert_equal(config.suffixes, fallback.suffixes)
      assert_equal(config.basenames - ['lib'], fallback.basenames)
      assert_equal(Package.name, HeartbeatFallback::PACKAGE_NAME)
    end

    def test_defaults_match_application_yaml
      fallback = HeartbeatFallback.new('postgresql_dump', dirs: @dirs)

      assert_equal(config['/heartbeat/base'], fallback.base)
      assert_equal(config['/heartbeat/timeout'], fallback.timeout)
      assert_predicate(fallback, :disable?)
      assert_nil(fallback.down('bundle check failed'))
    end

    def test_token_from_local
      write(1, 'local.yaml', 'heartbeat' => {'tokens' => {'postgresql_dump' => 'tok-local'}})
      fallback = HeartbeatFallback.new('postgresql_dump', dirs: @dirs)

      assert_false(fallback.disable?)
      assert_equal('tok-local', fallback.token)
      assert_predicate(HeartbeatFallback.new('mysql_dump', dirs: @dirs), :disable?)
    end

    # ⚠ periodic のファイル名はハイフンだが、設定のキーはアンダースコア
    def test_tool_name_is_normalized
      write(1, 'local.yaml', 'heartbeat' => {'tokens' => {'postgresql_dump' => 'tok-local'}})

      assert_equal('tok-local', HeartbeatFallback.new('postgresql-dump', dirs: @dirs).token)
    end

    # ホスト名 > local > application（葉ごと）
    def test_precedence
      write(0, 'application.yaml', 'heartbeat' => {'base' => 'https://app.example/api/push', 'timeout' => 5})
      write(1, 'local.yaml', 'heartbeat' => {'base' => 'https://local.example/api/push',
                                             'tokens' => {'postgresql_dump' => 'tok-local'}})
      write(1, 'node1.yaml', 'heartbeat' => {'tokens' => {'postgresql_dump' => 'tok-host'}})
      fallback = HeartbeatFallback.new('postgresql_dump', dirs: @dirs, hostname: 'node1')

      assert_equal('tok-host', fallback.token)
      assert_equal('https://local.example/api/push', fallback.base)
      assert_equal(5, fallback.timeout)
    end

    # ⚠ 同じ名前のファイルは、先に見つかった置き場が丸ごと勝つ（README の「shadow の罠」）
    def test_shadow
      write(0, 'local.yaml', 'sentry' => {'dsn' => nil})
      write(1, 'local.yaml', 'heartbeat' => {'tokens' => {'postgresql_dump' => 'tok-local'}})

      assert_predicate(HeartbeatFallback.new('postgresql_dump', dirs: @dirs), :disable?)
    end

    # ⚠ `null` を書いたキーは未定義と同じ（#104）
    def test_null_falls_through
      write(0, 'application.yaml', 'heartbeat' => {'base' => 'https://app.example/api/push'})
      write(1, 'local.yaml', 'heartbeat' => {'base' => nil, 'tokens' => {'postgresql_dump' => nil}})
      fallback = HeartbeatFallback.new('postgresql_dump', dirs: @dirs)

      assert_equal('https://app.example/api/push', fallback.base)
      assert_predicate(fallback, :disable?)
    end

    def test_uri
      write(1, 'local.yaml', 'heartbeat' => {'base' => 'https://kuma.example/api/push/',
                                             'tokens' => {'postgresql_dump' => 'tok-local'}})
      uri = HeartbeatFallback.new('postgresql_dump', dirs: @dirs).uri('down', "bundle check\nfailed #{'x' * 300}")

      assert_equal('/api/push/tok-local', uri.path)
      assert_equal('down', URI.decode_www_form(uri.query).to_h['status'])
      assert_equal(HeartbeatFallback::MESSAGE_LIMIT, URI.decode_www_form(uri.query).to_h['msg'].length)
      assert_match(/\Abundle check failed x/, URI.decode_www_form(uri.query).to_h['msg'])
    end

    # ⚠ Net::HTTP#get は 4xx / 5xx でも例外にしない。届いていないのに成功にしない
    def test_verify
      fallback = HeartbeatFallback.new('postgresql_dump', dirs: @dirs)

      assert_equal('200', fallback.verify('200'))
      ['302', '404', '502'].each do |code|
        error = assert_raise(HeartbeatFallback::ResponseError) {fallback.verify(code)}

        assert_equal("HTTP #{code}", error.message)
      end
    end

    # ⚠⚠ bundle が壊れているときに動く道具。gem を require したら意味が無い
    def test_stdlib_only
      [
        'app/lib/writers_base/heartbeat_fallback.rb',
        'bin/heartbeat_down.rb',
      ].each do |path|
        source = File.read(File.join(Environment.dir, path))
        requires = source.scan(/^\s*require ['"]([^'"]+)['"]/).flatten

        assert_empty(requires - ['date', 'net/http', 'socket', 'uri', 'yaml'], path)
        assert_not_match(/Bundler|Ginseng|Config\.instance/, source.gsub(/^\s*#.*$/, ''), path)
      end
    end

    private

    def write(index, name, body)
      File.write(File.join(@dirs[index], name), body.to_yaml)
    end
  end
end
