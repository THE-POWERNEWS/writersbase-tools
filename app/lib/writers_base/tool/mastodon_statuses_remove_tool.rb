module WritersBase
  # 古いリモート投稿を消す（`tootctl statuses remove`・#162）。
  #
  # ⚠ 受け持つのは**着地したあとの週 1 回分**。初回の大掃除（1 台あたり千万件単位）は
  # 利用側が手で進める（pooza/chubo2#261）。
  # ⚠⚠ `statuses remove` は pgbouncer を通すと動かない。挟んでいるノードは
  # `/mastodon_statuses_remove/env/DB_PORT` で PostgreSQL へ直接つなぐ（`MastodonTootctl#tootctl_env`）。
  # ⚠ `--compress-database` は長時間ロックを取るので既定に入れない。
  class MastodonStatusesRemoveTool < Tool
    include TootctlCommands

    def description
      return 'Mastodonの古いリモート投稿を削除します。'
    end
  end
end
