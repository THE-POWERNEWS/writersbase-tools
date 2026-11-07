#!/usr/bin/env bash
# 利用側（chubo2・writersbase-env）で tools に関わる動きを出す。⚠ こちらは当番ではない。要求の出どころなので見る。
# 使い方: consumers.sh <前回の日付 YYYY-MM-DD>
set -u
since=${1:?前回の日付（YYYY-MM-DD）を渡す}
chubo2=${CHUBO2_DIR:-$HOME/repos/chubo2}
echo '## pooza/chubo2'
if git -C "$chubo2" fetch -q origin; then
  echo "- 配る版（platform yaml）"
  for f in freebsd ubuntu; do
    v=$(git -C "$chubo2" show "origin/main:config/platform/$f.yaml" | sed -n '/^writersbase_tools:/,/^[a-z]/p' | grep -m1 'version:' | awk '{print $2}')
    echo "  $f: ${v:-🔴 取得失敗}"
  done
  echo "- $since 以降のコミット（tools に触れたもの・同期手順で見る docs）"
  git -C "$chubo2" log origin/main --since="$since" --format='  %h %cs %s' -i --grep='writersbase' --grep='wb ' --grep='periodic'
  git -C "$chubo2" log origin/main --since="$since" --format='  %h %cs %s（docs）' -- docs/infra-common.md docs/infra-misskey.md
else
  echo '🔴 取得失敗: chubo2 を fetch できない（未確認として報告する）'
fi
echo '- open Issue（writersbase-tools に触れるもの）'
gh issue list -R pooza/chubo2 --state open --search 'writersbase-tools in:title,body' --limit 30 --json number,title,updatedAt \
  --jq '.[]|"  #\(.number) \(.updatedAt[0:10]) \(.title)"' || echo '  🔴 取得失敗'
echo '- 閉じた Issue（'"$since"' 以降・writersbase-tools に触れるもの）'
gh issue list -R pooza/chubo2 --state closed --search "writersbase-tools in:title,body closed:>=$since" --limit 30 --json number,title,closedAt \
  --jq '.[]|"  #\(.number) \(.closedAt[0:10]) \(.title)"' || echo '  🔴 取得失敗'

echo '## THE-POWERNEWS/writersbase-env'
gh api 'repos/THE-POWERNEWS/writersbase-env/commits?path=config/platform/ubuntu.yaml&per_page=3' \
  --jq '.[]|"  ubuntu.yaml \(.sha[0:7]) \(.commit.committer.date[0:10]) \(.commit.message | split("\n")[0])"' || echo '  🔴 取得失敗'
gh issue list -R THE-POWERNEWS/writersbase-env --state open --search 'tools in:title' --limit 20 --json number,title,updatedAt \
  --jq '.[]|"  #\(.number) \(.updatedAt[0:10]) \(.title)"' || echo '  🔴 取得失敗'
