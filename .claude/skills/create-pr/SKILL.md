---
name: create-pr
description: 現在のブランチからGitHubのPRを作成する。コミット内容とissue番号をもとにタイトル・本文を自動生成する。
allowed-tools: Bash
---

## 現在のブランチ情報

!`git branch --show-current`

!`git log origin/main..HEAD --oneline 2>/dev/null || git log main..HEAD --oneline`

## PR テンプレート（`.github/pull_request_template.md`）

!`cat .github/pull_request_template.md`

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

### Step 3: PR タイトルと本文を生成する

ブランチ名・コミットメッセージ・関連 issue 番号（ブランチ名の `feature/<番号>-` から取得）をもとに：

- **タイトル**: コミットメッセージ or ブランチ名から簡潔に（70文字以内）
- **本文**: 上記の PR テンプレート（`.github/pull_request_template.md`）の見出し構成・順序をそのまま使い、各項目を埋める。本文の形式はテンプレートを唯一の定義とし、見出しの追加・削除・改名はしない。上記にテンプレートが表示されていない場合は `cat .github/pull_request_template.md` で読み込む。
  - 「関連issue」: ブランチ名から取得した issue 番号で `Closes #<番号>` とする。番号がない場合は「なし」と書く
  - HTML コメント（`<!-- -->`）は実際の記述に置き換えるか削除する
  - 該当しない項目（UI 変更がない場合のスクリーンショットなど）は「なし」と書く
  - 動作確認のチェックリストは、実際に通したもの・確認したものだけにチェック（`[x]`）を入れる
  - 本文の末尾に `🤖 Generated with [Claude Code](https://claude.com/claude-code)` を付ける

### Step 4: PR を作成する

```bash
gh pr create --title "<タイトル>" --body "<本文>"
```

作成後、PR の URL をユーザーに報告する。
