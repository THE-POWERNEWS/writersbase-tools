module WritersBase
  class CommandLine < Ginseng::CommandLine
    include Package

    # ⚠⚠ **引数そのものが資格情報になることがある**（モロヘイヤの webhook URL は
    # インスタンス URI ＋ トークン ＋ salt の SHA256）。伏せる口（`secrets` / `masked`）は
    # **ginseng-core v1.24.0 の本体**にある（pooza/ginseng-core#642）。
    # ⚠ `log_exec`（private）を写経して上書きしていたのは #65 〜 #82 の受け皿で、
    # **本体が形を変えると黙ってズレる**ので外した。ここで上書きし直さないこと。
  end
end
