module WritersBase
  class RsyncBackupTool < Tool
    ENTRY_KEYS = ['src', 'name'].freeze
    DOT_PARTS = ['.', '..'].freeze
    INVALID_NAME_PARTS = ['', *DOT_PARTS].freeze

    def exec(args = {})
      result = {success: [], failure: []}
      # ⚠⚠ `rsync --delete` を使う道具なので、宛先が無いまま走らせない。
      # ⚠ ソースごとの失敗にはせず、設定の誤りとして 1 件で落とす（#67）
      raise Ginseng::ConfigError, "'/#{underscore}/dest' not found" if dest.blank?
      entries.each do |entry|
        sync(entry, result)
      rescue => e
        logger.error(tool: underscore, src: entry[:src], error: e.message.strip)
        result[:failure].push(src: entry[:src], error: e.message.strip)
      end
      return result
    end

    def description
      return 'rsyncでファイルを外部サーバーにバックアップします。'
    end

    # 送り元と、`dest` の下に作る送り先の名前の組（#188）。
    #
    # `sources` の要素は文字列か `{src:, name:}`。文字列は従来どおり**送り元の絶対パスが
    # そのまま送り先に生える**（`/etc` → `<dest>/etc`）。`name` を書くと `<dest>/<name>` へ送る
    # （旧 ginseng の `rsync` の `dest:` に当たる。kues や MINC の機を移すため）。
    #
    # ⚠⚠ **送り先が重なる設定は、1 件も送らずに設定エラーで落とす。**`--delete` を使うので、
    # 親の側が子の側の中身を毎回消し、子の側が書き直す形になる。
    def entries
      entries = sources.map {|source| entry(source)}
      validate_overlaps(entries)
      return entries
    end

    def remote_path(entry)
      host, path = dest.split(':', 2)
      return "#{host}:#{File.join(path, entry[:name])}"
    end

    def rsync_args(entry)
      return [
        'rsync', '-avz', '--delete', '--mkpath',
        *excludes.flat_map {|pattern| ['--exclude', pattern]},
        "#{entry[:src]}/",
        remote_path(entry)
      ]
    end

    private

    def sync(entry, result)
      logger.info(tool: underscore, src: entry[:src], dest: remote_path(entry), message: '同期開始')
      execute(rsync_args(entry))
      logger.info(tool: underscore, src: entry[:src], dest: remote_path(entry), message: '同期完了')
      result[:success].push(entry[:src])
    end

    # ⚠⚠ **`to_s` で丸めないこと**（Codex P1）。YAML の空の要素（`- ` だけの行）が `''` になり、
    # 送り元が `/`・送り先が `dest` の直下になって、`--delete` が受け側を丸ごと書き換える
    def entry(source)
      return legacy_entry(source) if source.is_a?(String)
      raise config_error("invalid source: #{source.inspect}") unless source.is_a?(Hash)
      source = source.transform_keys(&:to_s)
      # ⚠ 旧 ginseng の `dest:` をそのまま写すと、黙って `name` 無しの扱いになる。綴りの誤りは落とす
      unknown = source.keys - ENTRY_KEYS
      raise config_error("unknown keys: #{unknown.join(', ')}") if unknown.present?
      src = valid_src(source['src'])
      name = source['name'].to_s
      raise config_error("invalid name: '#{name}' (#{src})") unless valid_name?(name)
      return {src:, name:}
    end

    # ⚠ 文字列は送り元のパスがそのまま送り先の名前になるので、`.` / `..` の段を許さない
    # （Codex P1）。`/srv/../etc` は受け側で `<dest>/etc` に解決され、重なりの検査をすり抜ける。
    # `..` は `dest` の外へ出る送り先にもなる
    def legacy_entry(source)
      src = valid_src(source)
      raise config_error("invalid src: '#{src}'") if src.split('/').intersect?(DOT_PARTS)
      return {src:, name: src}
    end

    def valid_src(src)
      return src if src.is_a?(String) && src.strip.present?
      raise config_error("invalid src: #{src.inspect}")
    end

    # `dest` の下の相対名だけを許す（`dest` の外へ出る名前・空の段を含む名前は落とす）
    def valid_name?(name)
      return false if name.start_with?('/')
      parts = name.split('/', -1)
      return parts.present? && !parts.intersect?(INVALID_NAME_PARTS)
    end

    def config_error(message)
      return Ginseng::ConfigError.new("'/#{underscore}/sources' #{message}")
    end

    def validate_overlaps(entries)
      paths = entries.map {|entry| normalize(entry[:name])}
      paths.combination(2) do |a, b|
        next unless overlap?(a, b)
        raise config_error("overlapping destinations: #{a}, #{b}")
      end
    end

    def normalize(name)
      return File.join('/', name).squeeze('/').chomp('/').presence || '/'
    end

    def overlap?(path_a, path_b)
      return true if path_a == path_b || [path_a, path_b].include?('/')
      return path_a.start_with?("#{path_b}/") || path_b.start_with?("#{path_a}/")
    end

    def dest = config["/#{underscore}/dest"]
    def excludes = config.lookup("/#{underscore}/excludes", [])
  end
end
