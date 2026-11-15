#!/usr/bin/env bash
# 直近にマージされた PR に、消化していないコメントが無いかを見る。
# Codex の結果は 4 経路（review・インライン・PR 本体のコメント・PR へのリアクション）で来るので全部読む。
# ⚠ bot だけを見ない。他リポジトリのセッションが pooza として申し送りを置くことがあるので、人のコメントも出す。
# 使い方: codex_channels.sh <PR番号>...   引数なしなら直近にマージされた 5 本
# ⚠ pipefail が無いと、gh が落ちても後ろの jq が空の入力を [] として成功させ、確認していないのに 0 で終わる
set -euo pipefail
r=repos/THE-POWERNEWS/writersbase-tools
bot='chatgpt-codex-connector[bot]'
prs=("$@")
if [ "${#prs[@]}" -eq 0 ]; then
  # ⚠ プロセス置換の中で gh が落ちても mapfile は成功するので、先に変数へ受けて終了コードを見る
  #   （「取れなかった」を「PR が無い」と読まないため）
  if ! list=$(gh pr list --state merged --limit 5 --json number --jq '.[].number'); then
    echo '⚠ マージ済みの PR の一覧を取れなかった（確認は未完了）' >&2
    exit 1
  fi
  [ -n "$list" ] && mapfile -t prs <<<"$list"
fi
for n in "${prs[@]}"; do
  echo "=== #$n"
  gh api --paginate "$r/pulls/$n/reviews" --jq ".[]|\"review \(.user.login) \(.state) \(.submitted_at) \(.commit_id[0:7])\""
  # ⚠ 全ページを 1 本の配列にまとめてから読む（ページをまたいだ返信を「無」と読まないため）
  gh api --paginate "$r/pulls/$n/comments?per_page=100" | jq -rs --arg bot "$bot" '
    add // [] | . as $all
    | $all[]
    | if .in_reply_to_id == null then
        .id as $id
        | (any($all[]; .in_reply_to_id == $id)) as $replied
        | ((.reactions["+1"] + .reactions["-1"]) > 0) as $reacted
        | "inline \(.user.login) \(.path):\(.line // .original_line) 返信=\(if $replied then "済" else "無" end) リアクション=\(if $reacted then "済" else "無" end)",
          (if .user.login == $bot then
             (if $replied then empty else "  🔴 未処理\n" + (.body | gsub("(?m)^"; "  | ")) end)
           else .body | gsub("(?m)^"; "  | ") end)
      # 返信は人のものだけ全文で出す（bot の返信は無い。人の申し送りが返信に書かれることがある）
      elif .user.login != $bot then
        "inline-reply \(.user.login) \(.path):\(.line // .original_line) → \(.in_reply_to_id)\n" + (.body | gsub("(?m)^"; "  | "))
      else empty end'
  # PR 本体のコメント。bot は 1 行目だけ、人は全文（申し送りの取りこぼしを防ぐ）
  gh api --paginate "$r/issues/$n/comments" | jq -rs --arg bot "$bot" '
    add // [] | .[]
    | if .user.login == $bot
      then "comment \(.user.login) \(.created_at) \(.body | split("\n") | map(select(test("Codex Review")) | gsub("<[^>]*>"; "") | gsub("\\*"; "")) | first // "(本文なし)")"
      else "comment \(.user.login) \(.created_at)\n" + (.body | gsub("(?m)^"; "  | ")) end'
  gh api --paginate "$r/issues/$n/reactions" --jq ".[]|\"reaction \(.user.login) \(.content) \(.created_at)\""
done
