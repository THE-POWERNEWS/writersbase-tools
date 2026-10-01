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
  end
end
