require 'date'
require 'net/http'
require 'socket'
require 'uri'
require 'yaml'

module WritersBase
  # `bin/wb` まで届かない失敗を Uptime Kuma の push モニタへ `down` で送る（#174）。
  #
  # 🔴 **periodic のスクリプトが `bundle check` で落ちると、Ruby（`bin/wb`）まで届かない。**
  # Sentry にもログにも何も出ず、Kuma が赤くなるのは interval 切れ（daily は 32 時間）を
  # 待ってから（pooza/chubo2#240: FreeBSD を 15.1 へ上げた DNS 機 2 台で、pdns の日次
  # ダンプが 4 日止まった）。そのときに `Heartbeat#down` の代わりを務める。
  #
  # ⚠⚠ **stdlib だけで書く。**bundle が壊れているときに動く道具なので、`Bundler.require` にも
  # ginseng-core にも触れない（`Config` / `HTTP` / `Logger` は使えない）。`bin/heartbeat_down.rb` は
  # このファイルだけを `require_relative` する。**ここで gem を require しないこと。**
  #
  # ⚠⚠ **設定の読み方は `Ginseng::Config#load` の写し。**置き場（`dirs`）・拡張子・
  # 「ホスト名 > local > application」の順・「同じ名前のファイルは先に見つかった置き場が勝つ」
  # （shadow）を揃えてある。本体とずれていないことは `HeartbeatFallbackTest` で見る。
  #
  # ⚠ push URL はそれ自体が資格情報（#121）。**引数にも標準出力にも載せない。**
  # 失敗しても例外のクラス名しか出さない（本文に URL が載りうる）。
  #
  # ⚠ **`ruby` 自体が起動しない止まり方（2026-07-18 に pkg から ruby33 が消えた型）は
  # これでも拾えない。**そこは従来どおり Kuma の interval 切れが受け持つ。
  class HeartbeatFallback
    DEFAULT_BASE = 'https://uptime.b-shock.org/api/push'.freeze
    DEFAULT_TIMEOUT = 20
    MESSAGE_LIMIT = 200
    PACKAGE_NAME = 'writersbase-tools'.freeze
    PERMITTED_YAML_CLASSES = [Date, Time, DateTime].freeze

    def initialize(tool, dirs: nil, hostname: Socket.gethostname)
      @tool = tool.to_s.tr('-', '_').downcase
      @dirs = dirs || default_dirs
      @hostname = hostname
    end

    # ⚠ トークンを書いたツールだけ送る（`Heartbeat#disable?` と同じ）
    def disable?
      return token.to_s.empty?
    end

    def down(message)
      return nil if disable?
      uri = uri('down', message)
      return Net::HTTP.start(uri.host, uri.port, **http_options(uri)) do |http|
        http.get(uri.request_uri).code
      end
    end

    def uri(status, message)
      uri = URI.parse("#{base.to_s.chomp('/')}/#{token}")
      msg = message.to_s.gsub(/\s+/, ' ').strip[0, MESSAGE_LIMIT]
      uri.query = URI.encode_www_form(status:, msg:)
      return uri
    end

    def base
      return lookup('heartbeat', 'base') || DEFAULT_BASE
    end

    def timeout
      return lookup('heartbeat', 'timeout') || DEFAULT_TIMEOUT
    end

    def token
      return lookup('heartbeat', 'tokens', @tool)
    end

    def default_dirs
      return [
        File.join(File.expand_path('../../..', __dir__), 'config'),
        File.join('/usr/local/etc', PACKAGE_NAME),
        File.join('/etc', PACKAGE_NAME),
      ]
    end

    def suffixes
      return ['.yaml', '.yml']
    end

    # ⚠ 本体の `lib` は ginseng-core 自身の既定で、heartbeat の設定を持たないので読まない
    def basenames
      return [@hostname, 'local', 'application']
    end

    private

    def http_options(uri)
      return {use_ssl: uri.scheme == 'https', open_timeout: timeout, read_timeout: timeout}
    end

    # ⚠ 本体は葉ごとに上書きする（`key_flatten` → `update`）ので、優先順に最初の非 nil を採る。
    # `null` を書いたキーは本体でも「未定義」になる（#104）。
    def lookup(*keys)
      sources.each do |source|
        value = keys.inject(source) {|node, key| node.is_a?(Hash) ? node[key] : nil}
        return value unless value.nil? || value.is_a?(Hash)
      end
      return nil
    end

    def sources
      @sources ||= basenames.filter_map {|basename| load_file(basename)}
      return @sources
    end

    def load_file(basename)
      @dirs.each do |dir|
        suffixes.each do |suffix|
          path = File.join(dir, "#{basename}#{suffix}")
          next unless File.file?(path)
          return YAML.load_file(path, permitted_classes: PERMITTED_YAML_CLASSES)
        end
      end
      return nil
    end
  end
end
