module WritersBase
  # ⚠⚠ **マスクの正本は Ginseng::Masking。**以前はここに `deep_mask_keys` という
  # 同等品を置き、`/logger/keys_to_mask` で対象を持っていたが、
  #
  # - `Ginseng::Logger#mask` と**名前が衝突**していた（こちらは引数を取らず
  #   `/logger/mask` を返す）。ginseng-core 1.23 系は `create_message` から
  #   `mask(src)` を呼ぶので、**ArgumentError → fail closed で全行が
  #   `_mask_error` になる**（実測）
  # - キー名でしか判定せず、**URL のクエリやパスに埋まった資格情報**には
  #   効かなかった（#66）
  #
  # ⚠ 対象は `config/application.yaml` の `/logger/mask_fields` などで**足す**。
  # 既定（`Ginseng::Masking::MASK_FIELDS` ほか）とは合成され、**減らす方向へは
  # 効かない**。
  class Logger < Ginseng::Logger
    include Package
  end
end
