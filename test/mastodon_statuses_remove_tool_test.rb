module WritersBase
  class MastodonStatusesRemoveToolTest < TestCase
    ENV_KEY = '/mastodon_statuses_remove/env/DB_PORT'.freeze

    def setup
      @tool = Tool.create('mastodon_statuses_remove')
    end

    def teardown
      config.delete(ENV_KEY)
      config.delete('/mastodon_statuses_remove/env/RAILS_ENV')
      config.delete('/mastodon_statuses_remove/env/DB-PORT')
    end

    def test_exec
      result = @tool.exec

      assert_kind_of(Array, result[:success])
      assert_kind_of(Array, result[:failure])
    end

    def test_description
      assert_kind_of(String, @tool.description)
    end

    # ⚠ `--compress-database` は長時間ロックを取るので既定に入れない（#162）
    def test_default_commands
      assert_equal(['statuses remove --days 90'], @tool.commands)
    end

    def test_env_absent
      command = @tool.send(:login_command, ['statuses', 'remove'])

      assert_equal({'RAILS_ENV' => config['/mastodon/rails_env']}, command.env)
    end

    # pgbouncer を挟むノードは DB_PORT で PostgreSQL へ直接つなぐ（#162）
    def test_env
      config[ENV_KEY] = 5432
      command = @tool.send(:login_command, ['statuses', 'remove'])

      assert_equal('5432', command.env['DB_PORT'])
      assert_equal(config['/mastodon/rails_env'], command.env['RAILS_ENV'])
    end

    # ⚠ ツールごとの設定なので、ほかの tootctl の道具には渡らない
    def test_env_is_per_tool
      config[ENV_KEY] = 5432
      command = Tool.create('mastodon_maintenance').send(:login_command, ['version'])

      assert_nil(command.env['DB_PORT'])
    end

    # ⚠ RAILS_ENV は /mastodon/rails_env が正本
    def test_rails_env_wins
      config['/mastodon_statuses_remove/env/RAILS_ENV'] = 'development'
      command = @tool.send(:login_command, ['version'])

      assert_equal(config['/mastodon/rails_env'], command.env['RAILS_ENV'])
    end

    def test_invalid_env_name
      config['/mastodon_statuses_remove/env/DB-PORT'] = 5432

      assert_raise(RuntimeError) {@tool.send(:login_command, ['version'])}
    end

    # ⚠⚠ 日本語のタグ名が `sudo ... sh -c` と `bash -lc` の 2 段を通っても崩れないこと（#162）。
    # cron 相当（LANG=C）でも確かめる
    def test_multibyte_tags
      arg = '--keep-tags=precure_fun,宮本佳那子'
      command = @tool.send(:login_command, ['printf', '%s\n', *"statuses remove #{arg}".split(/\s+/)])
      script = command.to_s.sub(/\Abash -lc /, 'bash -c ')
      stdout, status = Open3.capture2({'LANG' => 'C', 'LC_ALL' => 'C'}, "sh -c #{script.shellescape}")

      assert_predicate(status, :success?)
      assert_equal(['statuses', 'remove', arg], stdout.force_encoding('UTF-8').split("\n"))
    end

    # ⚠⚠ `--keep-tags` の綴りを間違えても tootctl は黙っている。手がかりの行を
    # periodic 経由でもログへ残す（#175）
    def test_output_summary
      stdout = [
        'Extract the deletion target from statuses... This might take a while...',
        'Keeping statuses tagged with: precure_fun, 美食丼',
        '',
        "  0% |\r 50% |=====\r100% |==========",
        'Progress: |==========================================|',
        "\e[32mDone after 1.5s, removed 10 out of 12 statuses.\e[0m",
      ].join("\n")
      summary = @tool.send(:output_summary, command_with(stdout))

      assert_includes(summary, 'Keeping statuses tagged with: precure_fun, 美食丼')
      assert_includes(summary, 'Done after 1.5s, removed 10 out of 12 statuses.')
      assert_not_match(/\e|\r|\n\n|Progress:/, summary)
    end

    # ⚠ 長い行は journald が捨て、FreeBSD の syslogd は 8,087 バイトで切り詰める（#119）。
    # 全部が 3 バイト文字でも収まること
    def test_output_summary_is_abbreviated
      stdout = ['Keeping statuses tagged with: tag', *Array.new(500) {|i| "進捗 #{i}"}, 'Done after 1s'].join("\n")
      summary = @tool.send(:output_summary, command_with(stdout))

      assert_operator(summary.to_json.bytesize, :<, 7000)
      assert_includes(summary, 'Keeping statuses tagged with: tag')
      assert_includes(summary, 'Done after 1s')
    end

    # ⚠ テストでは tootctl を走らせないので stdout は nil。壊れたバイト列でも落とさない
    # （ここで例外になると、成功したコマンドが失敗として数えられる）
    def test_output_summary_never_raises
      assert_equal('', @tool.send(:output_summary, command_with(nil)))
      assert_kind_of(String, @tool.send(:output_summary, command_with("Done \xFF".b.force_encoding('UTF-8'))))
    end

    private

    def command_with(stdout)
      command = @tool.send(:login_command, ['version'])
      command.define_singleton_method(:stdout) {stdout}
      return command
    end
  end
end
