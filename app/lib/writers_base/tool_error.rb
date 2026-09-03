module WritersBase
  # 道具が自分で握った失敗（`result[:failure]`）を、まとめて 1 件の例外にするための型。
  #
  # ⚠⚠ 各ツールは失敗を `rescue` して `result[:failure]` に積み、**正常に return する**。
  # そのままでは bin/wb の集約点に例外が届かず、Sentry へ 1 件も飛ばないうえ
  # 終了コードも 0 になる（cron / periodic からは成功に見える）ので、
  # 実行の最後にこれを投げて #37 の経路へ載せる（#64）。
  class ToolError < Ginseng::Error
    include Package
  end
end
