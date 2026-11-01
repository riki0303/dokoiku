---
name: create-pr
description: 現在のブランチからGitHubのPRを作成する。コミット内容とissue番号をもとにタイトル・本文を自動生成する。
allowed-tools: Bash
---

## 現在のブランチ情報

!`git branch --show-current`

!`git log origin/main..HEAD --oneline 2>/dev/null || git log main..HEAD --oneline`

## PR テンプレート（`.github/pull_request_template.md`）

!`cat "$(git rev-parse --show-toplevel)/.github/pull_request_template.md" 2>/dev/null || echo "(テンプレートが見つかりません)"`

## 手順

### Step 1: 状態確認

現在のブランチとコミット差分を確認する。

未コミットの変更がある場合はユーザーに伝えて、コミットするか確認する。

### Step 2: プッシュ

ブランチをリモートにプッシュする：

```bash
git push -u origin <current-branch>
```

pre-push フックが失敗した場合は原因を調査して修正する。

### Step 3: スクリーンショットを画像用ブランチに push する

`/start-issue` のブラウザ確認で `tmp/screenshots/<issue番号>/` に画像を残している場合だけ行う。なければこの Step は飛ばす（issue 番号の決め方は Step 4 と同じ）。

画像は main と履歴を共有しない orphan ブランチ `screenshots` の `issue-<issue番号>/` に置き、PR 本文からコミット SHA 固定の URL で参照する。main には画像を入れない。リポジトリは公開されているので、push する前に画像を見て、実在の個人情報や秘密情報が写っていないことを確認する。

```bash
ISSUE=<issue番号>
WT=$(mktemp -d)/screenshots
if git ls-remote --exit-code --heads origin screenshots >/dev/null; then
  git fetch origin screenshots
  git worktree add --detach "$WT" origin/screenshots
else
  git worktree add --orphan -b screenshots "$WT"   # 初回だけ。README.md も置く
fi
mkdir -p "$WT/issue-$ISSUE"
cp tmp/screenshots/$ISSUE/* "$WT/issue-$ISSUE/"
git -C "$WT" add "issue-$ISSUE"
git -C "$WT" commit -m "#$ISSUE のスクリーンショットを追加"
git -C "$WT" push origin HEAD:screenshots
SHA=$(git -C "$WT" rev-parse HEAD)
git worktree remove "$WT"
gh repo view --json nameWithOwner -q .nameWithOwner   # <owner>/<repo>
```

画像の URL は `https://raw.githubusercontent.com/<owner>/<repo>/$SHA/issue-$ISSUE/<ファイル名>` になる。ブランチ名ではなく SHA で参照するので、あとで画像を足したり消したりしても既存の PR の表示は変わらない。

### Step 4: PR タイトルと本文を生成する

#### issue 番号を決める

次の順で取得する：

1. ブランチ名の `feature/<番号>-` から取得する
2. 取れなければ、コミットメッセージ中の `(#<番号>)` から取得する
3. それでも取れなければ、関連 issue の有無をユーザーに確認する。issue がない場合は「なし」とする

#### タイトルと本文

- **タイトル**: コミットメッセージ or ブランチ名から簡潔に（70文字以内）
- **本文**: 上記の PR テンプレート（`.github/pull_request_template.md`）の見出し構成・順序をそのまま使い、各項目を埋める。本文の形式はテンプレートを唯一の定義とし、見出しの追加・削除・改名はしない。上記にテンプレートが表示されていない場合は `cat .github/pull_request_template.md` で読み込む。
  - 各項目はテンプレート内の HTML コメント（`<!-- -->`）の指示に従って埋め、コメント自体は本文から削除する
  - 「関連issue」は上で決めた番号で `Closes #<番号>` とする。番号がない場合は `Closes #` 行をまるごと `なし` に置き換える
  - 画面確認ができていない場合は「画面で動作を確認した」にチェックを付けず、「レビュー観点・補足」にその旨（未確認であること・理由）を書く
  - 「スクリーンショット」は、Step 3 で push した画像をファイル名の順に `![<画面の説明>](<URL>)` で貼る。画像の下に、画像だけでは分からない確認内容（入力値が残ること、画像のない操作など）を箇条書きで足す。画像がなく UI 変更もない場合は「なし」とする
  - 本文の末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を付ける

### Step 5: PR を作成する

本文はクォート付き heredoc（`<<'EOF'`）で渡し、`$` やバッククォートが展開されないようにする。タイトルはシングルクォートで囲む（タイトルにシングルクォートを含む場合は `'\''` でエスケープする）。

```bash
gh pr create --title '<タイトル>' --body-file - <<'EOF'
<本文>
EOF
```

作成後、PR の URL をユーザーに報告する。
