require 'bundler/setup'
require 'writers_base/refines'

module WritersBase
  using Refines

  def self.dir
    return File.expand_path('../..', __dir__)
  end

  def self.loader
    config = YAML.load_file(File.join(dir, 'config/autoload.yaml'))
    loader = Zeitwerk::Loader.new
    loader.inflector.inflect(config['inflections'])
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.collapse('app/lib/writers_base/*')
    return loader
  end

  def self.setup_debug
    Ricecream.disable
    return unless Environment.development?
    Ricecream.enable
    Ricecream.include_context = true
    Ricecream.colorize = true
    Ricecream.prefix = "#{Package.name} | "
    Ricecream.define_singleton_method(:arg_to_s, proc {|v| pp(v)})
  end

  # Sentry を初期化する（#37）。
  #
  # ⚠ **DSN が未設定なら何もしない。** 手元や、まだ DSN を配っていないサーバで
  # 勝手に送信を始めないための既定。
  #
  # ⚠ **初期化に失敗してもツールは止めない。** cron から呼ばれる道具なので、
  # 監視のための仕掛けが本業を落とすのは本末転倒。警告だけ出して先へ進む。
  def self.setup_sentry
    dsn = sentry_config('dsn')
    return if dsn.to_s.empty?
    Sentry.init do |config|
      config.dsn = dsn
      config.release = Package.version
      config.environment = sentry_config('environment') || Environment.type
      config.traces_sample_rate = sentry_config('traces_sample_rate', 0)
      # ⚠ 既定のままにする。true にするとユーザ名や IP が載る。
      config.send_default_pii = false
      config.before_send = method(:scrub_sentry_event)
    end
  rescue => e
    warn "Sentry initialization skipped: #{e.message}"
  end

  # Sentry の設定値を安全に読む。
  #
  # ⚠ **Ginseng::Config は値が nil のとき ConfigError を投げる。** 素で読むと
  # DSN 未設定という**普通の状態**で毎回 stderr に警告が出て、cron からの
  # 実行がメールを生む。既定値へ倒して黙らせる。
  def self.sentry_config(key, default = nil)
    value = Config.instance["/sentry/#{key}"]
    return value.nil? ? default : value
  rescue Ginseng::ConfigError
    return default
  end

  # 送信前に例外メッセージから資格情報を落とす。
  #
  # ⚠⚠ **マスクの正本は Ginseng::Masking。** ここで同等品を書くと対象の列が
  # 分かれて必ずズレるので、**使える版なら必ず `mask_urls_in` に通す**。
  #
  # ⚠ **いまの Gemfile.lock の ginseng-core にはまだ無い。** `mask_urls_in` は
  # あとから public になったもので、固定している版では `Logger#mask_url` が
  # `\\A` 錨のまま＝**例外メッセージに埋まった URL には効かない**。
  # ginseng-core を上げたら自動でそちらが効くようにしてあるが、それまで
  # 取りこぼさないよう `/sentry/scrub_patterns` 側にも URL の資格情報を入れてある。
  def self.scrub_sentry_event(event, _hint)
    event.exception&.values&.each do |ex| # rubocop:disable Style/HashEachMethods
      ex.value = scrub_sentry_text(ex.value)
      scrub_sentry_stacktrace(ex.stacktrace)
    end
    return event
  rescue => e
    warn "Sentry scrub skipped: #{e.message}"
    return event
  end

  # スタックトレースに載る**ソースの行**からも資格情報を落とす。
  #
  # ⚠ **Sentry は例外が起きた行の前後を丸ごと送る**（context_line / pre_context /
  # post_context）。例外メッセージだけ伏せても、その行のソースに資格情報が
  # 書いてあれば素通りする（実測で確認）。
  def self.scrub_sentry_stacktrace(stacktrace)
    stacktrace&.frames&.each do |frame|
      frame.context_line = scrub_sentry_text(frame.context_line)
      frame.pre_context = frame.pre_context&.map {|line| scrub_sentry_text(line)}
      frame.post_context = frame.post_context&.map {|line| scrub_sentry_text(line)}
    end
  end

  # Ginseng::Masking と同じ印。ログと Sentry で表記を揃える。
  SENTRY_FILTERED = '[FILTERED]'.freeze

  def self.scrub_sentry_text(text)
    return text unless text.is_a?(String)
    result = text
    result = sentry_masker.mask_urls_in(result) if sentry_masker.respond_to?(:mask_urls_in)
    sentry_scrub_patterns.each do |pattern|
      result = result.gsub(pattern, SENTRY_FILTERED)
    end
    return result
  end

  def self.sentry_masker
    # Logger は Ginseng::Masking を include している（版によっては未収録）。
    @sentry_masker ||= Logger.new
    return @sentry_masker
  end

  def self.sentry_scrub_patterns
    @sentry_scrub_patterns ||= sentry_config('scrub_patterns', []).map do |pattern|
      Regexp.new(pattern)
    end
    return @sentry_scrub_patterns
  end

  # 例外を Sentry へ送る。DSN 未設定なら何もしない。
  #
  # ⚠ **送ったら必ず flush する。** cron から呼ばれる道具は送信直後に exit するので、
  # 既定の非同期送信のままだとプロセスが先に消えてイベントが届かない。
  #
  # fingerprint にツール名を混ぜて、道具ごとにまとめる（別の道具の失敗が
  # 同じ issue に吸われないようにする）。
  def self.capture_error(error, tool: nil)
    return unless defined?(Sentry) && Sentry.initialized?
    Sentry.capture_exception(error, fingerprint: ['{{ default }}', tool].compact)
    Sentry.close
  rescue => e
    warn "Sentry capture skipped: #{e.message}"
  end

  def self.load_tasks
    finder = Ginseng::FileFinder.new
    finder.dir = File.join(dir, 'app/task')
    finder.patterns.push('*.rb')
    finder.patterns.push('*.rake')
    finder.exec.each {|f| require f}
  end

  Dir.chdir(dir)
  ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')
  Bundler.require
  loader.setup
  setup_sentry
  setup_debug
end
