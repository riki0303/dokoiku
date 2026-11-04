#!/usr/bin/env bash
# Claude Code Action 用: PR の行コメント（レビューコメント）を読み取り専用で取得して表示する
# gh api をそのまま許可すると -X DELETE や -f で書き込めてしまうため、
# メソッド（GET）とエンドポイントをこのスクリプト内で固定し、引数は数字だけ受け付ける
#
# 使い方: pr_review_comments.sh <PR番号> [レビューID]
#   レビューID なし: PR の全行コメント
#   レビューID あり: そのレビューに付いた行コメントだけ（pull_request_review_id で絞り込む）
set -euo pipefail

usage() {
  echo "使い方: $0 <PR番号> [レビューID]" >&2
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

pr_number="$1"
review_id="${2:-}"

if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
  echo "エラー: PR番号は数字で指定してください: $pr_number" >&2
  exit 1
fi

if [[ $# -eq 2 && ! "$review_id" =~ ^[0-9]+$ ]]; then
  echo "エラー: レビューIDは数字で指定してください: $review_id" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "エラー: GITHUB_REPOSITORY（owner/repo）が設定されていません" >&2
  exit 1
fi

# レビュー単位のエンドポイント（pulls/<PR>/reviews/<ID>/comments）は line / side / in_reply_to_id などを
# 返さないため、常に PR の全行コメントを取得し、レビュー ID 指定時は jq で絞り込む
endpoint="repos/${GITHUB_REPOSITORY}/pulls/${pr_number}/comments"

if [[ -n "$review_id" ]]; then
  # review_id は数字だけであることを検証済みなので jq に埋め込んでよい
  select_filter="select(.pull_request_review_id == ${review_id})"
else
  select_filter="."
fi

# line は古いコミットに対するコメント（outdated）だと null になるので original_line で補い、(outdated) と表示する
# 複数行にまたがるコメントは start_line（なければ original_start_line）から line までを表示する
jq_filter='.[] | '"${select_filter}"' | '\
'(if .line == null and .subject_type != "file" then " (outdated)" else "" end) as $outdated | '\
'(.start_line // .original_start_line) as $start | '\
'(.line // .original_line) as $end | '\
'"===== comment \(.id) =====\n'\
'file: \(.path)\n'\
'line: \(if $start != null and $start != $end then "\($start)-" else "" end)\($end // "-")\($outdated) (side: \(.side // "-"))\n'\
'in_reply_to: \(.in_reply_to_id // "-")\n'\
'review_id: \(.pull_request_review_id // "-")\n'\
'user: \(.user.login)\n'\
'--- body ---\n\(.body)\n'\
'--- diff_hunk ---\n\(.diff_hunk)\n"'

output="$(gh api --method GET --paginate "$endpoint" -f per_page=100 --jq "$jq_filter")"

# 0 件のとき何も出ないと「コメントが無い」のか「失敗した」のか区別できないため、明示する
if [[ -z "$output" ]]; then
  echo "該当する行コメントはありません（PR: ${pr_number}${review_id:+, レビューID: ${review_id}}）"
else
  printf '%s\n' "$output"
fi
