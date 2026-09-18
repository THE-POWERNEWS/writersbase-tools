module WritersBase
  class Config < Ginseng::Config
    include Package

    # 設定を読み、**未定義なら既定へ倒す**（#104）。
    #
    # ⚠⚠ **`Ginseng::Config#[]` は未定義キーで `ConfigError` を投げる。`nil` は返さない。**
    # そのため `config[...] || []` や `config[...] != false` は「キーが無くても動く」ように
    # 読めて、実際には**例外になる**。既定へ倒したいときは必ずここを通すこと。
    #
    # ⚠ `dsn: null` のように `null` を書くと**キーごと落ちる**ので、「未設定」と「未定義」は
    # 区別できない。どちらもここでは既定になる。
    #
    # ⚠⚠ **逆に「無ければ落ちてほしい」設定**（`postgresql_snapshot` の `target` / `dsn`・#87）
    # **はここを通さない。**素の `config[...]` のままにして、fail closed を保つこと。
    def lookup(key, default = nil)
      value = self[key]
      return value.nil? ? default : value
    rescue Ginseng::ConfigError
      return default
    end
  end
end
