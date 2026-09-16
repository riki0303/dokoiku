---
name: create-pr
description: 現在のブランチからGitHubのPRを作成する。コミット内容とissue番号をもとにタイトル・本文を自動生成する。
allowed-tools: Bash
---

## 現在のブランチ情報

!`git branch --show-current`

!`git log origin/main..HEAD --oneline 2>/dev/null || git log main..HEAD --oneline`

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
- **本文**:
  - `## Summary` — 変更内容を箇条書き3点以内
  - `## Test plan` — 確認すべき RSpec テストのチェックリスト
  - `Closes #<issue番号>`（issue番号がある場合）
  - `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

### Step 4: PR を作成する

```bash
gh pr create --title "<タイトル>" --body "<本文>"
```

作成後、PR の URL をユーザーに報告する。
