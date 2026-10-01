module WritersBase
  # Mastodon の tootctl 実行を login shell (bash -lc) 経由で行う共通処理。
  #
  # writersbase-tools 自体は OS 同梱の Ruby で動かす想定だが、Mastodon は
  # rbenv 管理の Ruby で動く。cron / periodic の非ログインシェルでは rbenv が
  # 初期化されず OS の Ruby にフォールバックし、Mastodon の bundle を未充足と
  # 誤判定する。そこで tootctl と bundle check だけは `bash -lc` を挟んで
  # mastodon ユーザーの rbenv を読み込ませる。
  module MastodonTootctl
    ENV_NAME_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    private

    # ⚠ secrets には「引数そのものが資格情報」であるものを渡す。ログにも例外にも
    # 出さないため（#65）。
    def tootctl_command(args, secrets: [])
      command = login_command(['bundle', 'exec', 'bin/tootctl', *args], secrets:)
      unless test?
        bundle_check!
        command.exec
        # ⚠ stderr が空のまま落ちることがあるので、Tool#command_error に寄せる
        # （空文字を raise すると「失敗したのに理由が空」になる）。伏字化も同じ経路
        raise command_error(command) if command.status.nonzero?
      end
      return command
    end

    def bundle_check!
      check = login_command(['bundle', 'check'])
      check.exec
      return if check.status.zero?
      raise [
        'Mastodonのbundleが未充足です。',
        "`cd #{mastodon_dir} && sudo -u #{mastodon_user} bundle install` を実行してください",
        "(#{check.stderr.strip})",
      ].join(' ')
    end

    def login_command(args, secrets: [])
      command = CommandLine.new(['bash', '-lc', Shellwords.join(args)])
      command.secrets = secrets
      command.user = mastodon_user
      command.env = tootctl_env.merge('RAILS_ENV' => mastodon_rails_env)
      command.dir = mastodon_dir
      return command
    end

    # `/<ツール名>/env` に書いた環境変数を tootctl へ渡す（#162）。既定は無し。
    # 例: `statuses remove` は pgbouncer を通すと動かない（一時テーブルと
    # `CREATE INDEX CONCURRENTLY` を使う）ので、`DB_PORT` で PostgreSQL へ直接つなぐ。
    #
    # ⚠⚠ **値は `sudo -u <user> env K=V ...` の引数に載り、`ps` から読める。**資格情報を置かないこと。
    # ⚠ `RAILS_ENV` は `/mastodon/rails_env` が勝つ（正本を 2 つにしない）。
    # ⚠ 設定は `/<ツール名>/env/<名前>` へ平らにされているので、接頭辞で拾う。
    def tootctl_env
      prefix = "/#{underscore}/env/"
      return config.each_with_object({}) do |(key, value), env|
        next unless key.start_with?(prefix)
        next if value.nil?
        name = key.delete_prefix(prefix)
        raise "#{key}: 環境変数の名前として使えません" unless ENV_NAME_PATTERN.match?(name)
        env[name] = value.to_s
      end
    end

    def mastodon_user = config['/mastodon/user']
    def mastodon_rails_env = config['/mastodon/rails_env']
    def mastodon_dir = config['/mastodon/dir']
  end
end
