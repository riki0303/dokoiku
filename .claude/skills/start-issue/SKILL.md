---
name: start-issue
description: GitHub issueを選択してブランチを作成し、プランモードで実装方針を作成する。新機能・バグ修正の開発を始めるときに使う。
argument-hint: [issue-number]
allowed-tools: Bash
---

## 現在のオープンIssue

!`gh issue list --limit 30 --state open --json number,title,labels 2>/dev/null | jq -r '.[] | "#\(.number) \(.title) [\(.labels | map(.name) | join(", "))]"' 2>/dev/null || echo "(gh CLI が利用できないか、issueが見つかりません)"`

## 手順

### Step 1: Issue を選択する

`$ARGUMENTS` に issue 番号が指定されている場合はそれを使う。
指定がない場合は、上記の一覧をユーザーに提示し、取り組む issue を選んでもらう。

選択後、issue の詳細を取得する：

```bash
gh issue view <issue番号> --json number,title,body,labels,assignees
```

issue のタイトルと本文を読み、実装内容を把握する。

### Step 2: main ブランチを最新化してブランチを作成する

```bash
git fetch origin main
git checkout main
git pull origin main
```

issue 番号とタイトルをもとにブランチ名を決める：
- 形式: `feature/<issue番号>-<英語スラッグ>`
- 例: `feature/42-add-proposal-search`
- スラッグはタイトルを英語で短く表現し、スペースをハイフンに変換する

```bash
git checkout -b feature/<issue番号>-<スラッグ>
```

ブランチを作成したらユーザーに報告する。

### Step 3: プランモードで実装方針を作成する

`docs/specs/` に関連する仕様書があれば確認する。

`EnterPlanMode` ツールを使ってプランモードに入り、以下の観点で実装方針を作成する：

1. **実装概要** — issue の内容と `docs/specs/` の仕様をもとに何を実装するか
2. **影響範囲** — 変更・追加が必要なファイル（モデル / コントローラー / ビュー / ポリシー / テスト）
3. **実装ステップ** — 順番に実施する作業の一覧
4. **テスト方針** — RSpec でどのテストを追加・修正するか

プランが完成したらユーザーに確認を求め、承認を得てから実装を開始する。

### Step 4: 実装内容をユーザーに報告する

実装完了後（developer / reviewer の完了報告を受けたあと）、以下の内容をユーザーに報告する：

1. **実装ファイル一覧** — 追加・変更したファイルのパス
2. **設計上の主な判断** — プランから変更した点や、非自明な実装判断
3. **テスト結果** — rspec / rubocop / brakeman / rails_best_practices の通過件数
4. **次のアクション** — PR 作成や残タスクの案内

> **注意**: このスキルではコミット・プッシュは行わない。コード変更のコミットと PR 作成は `/create-pr` スキルで行う。
