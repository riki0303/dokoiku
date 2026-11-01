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
   - JavaScript（Stimulus / Turbo）の動きなど、request spec では確認できない画面の挙動がある場合は system spec（`spec/system/`）を追加する
   - system spec の実行環境（Capybara とブラウザドライバ）が未導入なら、導入するかどうかをプランに含めてユーザーに確認する（勝手に gem を追加しない）
5. **ブラウザ確認の方針** — UI に変更がある場合（ビュー / CSS / JavaScript / 画面遷移）、ブラウザで確認する画面と操作の一覧

プランが完成したらユーザーに確認を求め、承認を得てから実装を開始する。

### Step 4: UI に変更がある場合はブラウザで動作確認する

ビュー・CSS・JavaScript・画面遷移のいずれかに変更がある場合、reviewer のレビュー対応が終わり全チェックが通ったあとに実施する。UI に変更がなければこの Step は飛ばす。

1. `.claude/launch.json` の設定で `preview_start` を使ってサーバーを起動する（Bash でサーバーを起動しない）
2. ログインが必要な画面は、ローカル環境でテスト用ユーザーを使う。用意の方法（サインアップ / 既存ユーザー）は事前にユーザーに確認する
3. プランの「ブラウザ確認の方針」に沿って画面を操作する（正常系・入力エラー・リンクや画面遷移など）
4. コンソールエラーとサーバーログにエラーがないことを確認する
5. 問題があれば developer に修正を依頼し、チェックを通したうえで再確認する
6. 確認した画面のスクリーンショットを撮り、Step 5 の報告に含める
   - PR に貼る画像は `tmp/screenshots/<issue番号>/` にコピーして残す（`/create-pr` がここから PR に貼る。`tmp/` は git 管理外）
   - ファイル名は `01-form.jpg` のように、番号と英語で画面の内容が分かる名前にする（番号順に PR に並ぶ）
   - 修正前の画面など、最終的な実装と違う画面は残さない
   - リポジトリは公開されているので、実在の個人情報や秘密情報が写った画像は残さない（テスト用のデータだけを使う）

### Step 5: 実装内容をユーザーに報告する

実装完了後（developer / reviewer の完了報告を受けたあと）、以下の内容をユーザーに報告する：

1. **実装ファイル一覧** — 追加・変更したファイルのパス
2. **設計上の主な判断** — プランから変更した点や、非自明な実装判断
3. **テスト結果** — rspec / rubocop / brakeman / rails_best_practices の通過件数
4. **ブラウザ確認の結果** — 確認した操作とスクリーンショット（UI 変更がない場合は「対象外」と書く）
5. **次のアクション** — PR 作成や残タスクの案内

> **注意**: このスキルではコミット・プッシュは行わない。コード変更のコミットと PR 作成は `/create-pr` スキルで行う。
