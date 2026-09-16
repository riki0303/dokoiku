---
name: define-requirements
description: 要件定義を対話的に行い、確定したらGitHub issueとして作成する。新機能・改善・バグ報告の起票に使う。
argument-hint: [テーマや機能名（省略可）]
allowed-tools: Bash, AskUserQuestion
model: opus
---

### Step 1: テーマを確認する

`$ARGUMENTS` にテーマがあればそれを出発点にする。なければ何を要件定義したいかを聞く。

### Step 2: 要件を対話的に整理する

一度にまとめて質問せず、会話の流れで以下を引き出す。

**必須**
- タイトル（50文字以内）
- 背景・課題
- やること / やらないこと
- 受け入れ条件

**任意**
- ラベル（`bug` / `enhancement` / `documentation` など）
- 優先度・関連issue番号

### Step 3: ドラフトを提示して確認する

```
## タイトル
## 背景・課題
## やること
## やらないこと
## 受け入れ条件
```

OKが得られたら Step 4 へ。修正があれば更新して再提示する。

### Step 4: GitHub issueを作成する

確定内容で `gh issue create` を実行する。ラベル未指定なら `--label` は省略。

作成後、issueのURLと番号を報告し、`/start-issue <番号>` で実装を開始できることを伝える。
