module WritersBase
  class ConfigTest < TestCase
    # ⚠⚠ Ginseng::Config#[] は未定義キーで ConfigError を投げる（nil を返さない）。
    # `config[...] || 既定` が効かないのはこのため（#104）
    def test_raises_on_undefined_key
      assert_raise(Ginseng::ConfigError) {config['/definitely_not_defined_20260919']}
    end

    # ⚠ 既定へ倒したいときの口。未定義でも例外にしない
    def test_lookup_falls_back_on_undefined_key
      assert_equal('fallback', config.lookup('/definitely_not_defined_20260919', 'fallback'))
      assert_nil(config.lookup('/definitely_not_defined_20260919'))
    end

    def test_lookup_returns_configured_value
      assert_equal(Package.name, config.lookup('/definitely_not_defined_20260919', Package.name))
      assert_equal(config['/package/name'], config.lookup('/package/name', 'fallback')) if config?('/package/name')
    end

    # ⚠⚠ `dsn: null` のように null を書くとキーごと落ちるので、「未設定」と「未定義」は
    # 区別できない。どちらも既定になる（#104）
    def test_lookup_treats_null_as_undefined
      omit('dsn が設定されている') if config?('/sentry/dsn')

      assert_equal('fallback', config.lookup('/sentry/dsn', 'fallback'))
    end
  end
end
