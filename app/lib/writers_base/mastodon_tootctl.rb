module WritersBase
  # Mastodon の tootctl 実行を login shell (bash -lc) 経由で行う共通処理。
  #
  # writersbase-tools 自体は OS 同梱の Ruby で動かす想定だが、Mastodon は
  # rbenv 管理の Ruby で動く。cron / periodic の非ログインシェルでは rbenv が
  # 初期化されず OS の Ruby にフォールバックし、Mastodon の bundle を未充足と
  # 誤判定する。そこで tootctl と bundle check だけは `bash -lc` を挟んで
  # mastodon ユーザーの rbenv を読み込ませる。
  module MastodonTootctl
    private

    def tootctl_command(args)
      command = login_command(['bundle', 'exec', 'bin/tootctl', *args])
      unless test?
        bundle_check!
        command.exec
        raise command.stderr if command.status.nonzero?
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

    def login_command(args)
      command = CommandLine.new(['bash', '-lc', Shellwords.join(args)])
      command.user = mastodon_user
      command.env = {'RAILS_ENV' => mastodon_rails_env}
      command.dir = mastodon_dir
      return command
    end

    def mastodon_user = config['/mastodon/user']
    def mastodon_rails_env = config['/mastodon/rails_env']
    def mastodon_dir = config['/mastodon/dir']
  end
end
