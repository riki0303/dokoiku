# Dependabot 自動マージとブランチ保護の設定手順

Dependabot のパッチ・マイナー更新 PR を、必須チェック（CI の 4 ジョブ）がすべて成功したあとに自動で merge するための設定手順です（Issue #86）。

ワークフロー（`.github/workflows/dependabot-auto-merge.yml`）はリポジトリに含まれていますが、
**GitHub の画面での設定（この手順書の内容）は手動で行う必要があります。**

> **重要: ワークフローを `main` に merge する前に、この手順書の設定を済ませてください。**
> ルールセット（必須ステータスチェック）がない状態でワークフローが動くと、`gh pr merge --auto` は
> CI を待たずにその場で merge しようとします（Allow auto-merge が OFF の場合はエラーになります）。

---

## 1. 自動マージの仕組み

1. Dependabot が PR を作成・更新すると、`Dependabot auto-merge` ワークフローが動きます
2. `dependabot/fetch-metadata` で更新の種類（update-type）を調べます
3. パッチ更新（`version-update:semver-patch`）かマイナー更新（`version-update:semver-minor`）なら、
   `gh pr merge --auto --merge` で **自動マージを予約** します（merge 方式は merge commit）
4. GitHub が、ルールセットで必須にした CI の 4 ジョブ（`brakeman` / `rubocop` / `rails_best_practices` / `rspec`）がすべて成功するのを待ってから merge します

| PR の種類 | どうなるか |
| --- | --- |
| Dependabot のパッチ・マイナー更新 | 自動マージが予約され、必須チェック成功後に merge される |
| Dependabot のパッチ・マイナー更新で必須チェックが失敗 | merge されずに残る（手で確認する） |
| Dependabot のメジャー更新 | 予約されない（今まで通り手でレビューして merge） |
| 更新の種類が判定できない PR（バージョンを比較できない更新。git 参照の gem、SHA 固定の action など） | 予約されない（安全側に倒している） |
| 人が作った PR | ワークフロー自体が動かない（対象外） |

- 対象の依存は bundler / github-actions / npm（セキュリティ更新）のすべてです。ecosystem では絞っていません
- 承認（Approve）は不要です。ルールセットの必須承認数を 0 にしているためです
- `bundler_audit` / `importmap_audit` は必須チェックではありません。これらが失敗（赤い ×）していても、必須の 4 ジョブが通れば自動マージされます（理由は 3 章を参照）

---

## 2. Allow auto-merge を ON にする

1. リポジトリの **Settings** を開く
2. 左メニューの **General** を開く
3. **Pull Requests** セクションまでスクロールする
4. **Allow auto-merge** にチェックを入れる（チェックを入れると自動で保存されます）

---

## 3. `main` のルールセットを作る

1. リポジトリの **Settings** を開く
2. 左メニューの **Rules** → **Rulesets** を開く
3. **New ruleset** → **New branch ruleset** を選ぶ
4. 以下のように設定する

### 基本設定

| 項目 | 設定値 |
| --- | --- |
| Ruleset Name | 任意（例: `main`） |
| Enforcement status | **Active** |
| Bypass list | **空のまま**（何も追加しない） |
| Target branches | **Add target** → **Include default branch** |

**Bypass list を空にする理由:** 空にすると、リポジトリの管理者（自分）も含めて全員がルールの対象になります。
つまり **自分も `main` に直接 push できなくなります**。これは「main 直接 push 禁止」を仕組みで強制するための意図通りの挙動です。

### Rules（ブランチのルール）

以下にチェックを入れます。ここに書いていないルールはチェックしません。

- **Restrict deletions**（`main` の削除を禁止）
- **Require a pull request before merging**（PR を必須にする＝直接 push を禁止）
  - **Required approvals**: **0**（自分で merge できる今の流れを維持するため）
- **Require status checks to pass**（必須チェックの成功を必須にする）
  - **Require branches to be up to date before merging**: **OFF**（チェックを外す）
  - **Add checks** で次の 4 つを追加する（`bundler_audit` / `importmap_audit` は追加しない）
    - `brakeman`
    - `rubocop`
    - `rails_best_practices`
    - `rspec`
- **Block force pushes**（force push を禁止）

最後に **Create** を押して保存します。

**「Require branches to be up to date before merging」を OFF にする理由:**
ON にすると、PR のブランチが最新の `main` を取り込んでいないと merge できなくなります。
Dependabot の PR が何件も溜まっているとき、1 件 merge するたびに残りの PR がすべて rebase 待ちになり、
自動マージが順番に詰まってしまうため OFF にします。

**`bundler_audit` / `importmap_audit` を必須チェックにしない理由:**
2 つの audit は `ci.yml` でこれまで通り動かし続けますが、必須にはしません。

- audit は PR の差分ではなく、Gemfile.lock / importmap に含まれる依存全体を、**毎回その時点で最新の脆弱性データベース** と照合します。
  データベースに新しい脆弱性が追加されると、PR の変更内容と関係なく、すべての PR で audit が落ちます。
  必須にすると、関係ない PR まで全部 merge できなくなります
- さらに、別々の gem にある脆弱性をそれぞれ直す PR どうしが、お互いに相手の直していない脆弱性で落ち合い、どちらも merge できなくなります
  （実例: この設定を入れた PR #88 自体も、`main` の rails 8.1.4 の脆弱性で `bundler_audit` が落ちました）
- 一方 `brakeman` は自分たちのコードと Gemfile.lock（Rails の版など）を、Gemfile.lock で固定した brakeman の版に含まれるルールで検査します。外部のデータベースは見ません。
  同じコードなら毎回同じ結果になるため、必須のまま残します

**必須チェック名について:**
必須チェックの名前は `.github/workflows/ci.yml` の **ジョブ名**（`jobs:` の直下のキー）と一致している必要があります。
`ci.yml` のジョブ名を変更したり、ジョブを追加・削除したりした場合は、**ルールセットの必須チェックも合わせて更新してください**。
更新しないと、存在しないチェックを待ち続けて PR が merge できなくなります。

---

## 4. 設定後の確認

- 人の PR で、必須チェック（4 ジョブ）が完了する前・失敗したときに merge ボタンが押せないこと（audit だけが失敗している場合は押せるのが正しい）
- `main` へ直接 push すると拒否されること
- Dependabot のパッチ・マイナー更新 PR に「Auto-merge enabled」と表示され、必須チェック成功後に merge されること

### 確認事項: github-actions の更新 PR が自動 merge まで進むか

github-actions の更新 PR は `.github/workflows/` 配下のファイルを変更します。
`GITHUB_TOKEN` で予約した自動 merge がこの種の PR でも通るかは **未確認** です。
最初に届いた github-actions の更新 PR で、必須チェック成功後に実際に merge まで進むかを確認してください。
merge されずに止まった場合は、手で merge してください。

---

## 5. 注意点

### audit が失敗していても自動マージされる

`bundler_audit` / `importmap_audit` は必須チェックではないため、これらが赤い × のままでも、必須の 4 ジョブが通れば自動マージされます。

そのため、更新によって推移的依存（直接書いていない依存）が既知の脆弱な版に変わる PR も、自動マージされることがあります。
通常は、Dependabot のセキュリティ更新が修正 PR を作ってくれます（パッチ・マイナー更新なら、それも自動マージされます。Settings → Code security で Dependabot security updates が ON になっている前提です）。
ただし次の場合は修正 PR が来ない、または手作業が必要になるため、**Dependabot アラート（Security タブ）で気づいたら手で対応してください**。

- 修正版がまだリリースされていない場合
- 修正にメジャー更新が必要な場合（メジャー更新は自動マージの対象外）

**本番デプロイ後に見直す候補:** PR で「新しく増えた脆弱性」だけを失敗させる差分方式の audit を導入し、audit を必須チェックに戻す。

### 自動マージで merge されたあと、`main` の CI は動かない

ワークフローの `GITHUB_TOKEN` で行った操作は、GitHub の仕様で他のワークフローを起動しません。
そのため、自動マージによる `main` への push では `ci.yml` の `push: main` トリガーが動きません。
merge 前に PR 上で必須チェックが通っており、デプロイ用のワークフローもないため、問題にならない想定です。

### ワークフロー導入前から open の Dependabot PR は自動では予約されない

ワークフローは PR の作成・更新時に動くため、ワークフローを `main` に入れる前から open になっている Dependabot PR には予約されません。
その PR に `@dependabot rebase` とコメントすると、Dependabot が PR を更新してワークフローが再実行され、パッチ・マイナー更新なら予約されます。

### 予約済みの Dependabot PR に人が commit を足すときは、先に予約を外す

自動マージが予約された PR に人が commit を追加しても、予約は残ったままです。
そのため CI が通ると、**人の変更ごと自動で merge されることがあります**。
Dependabot の PR を手で直すときは、先に PR の **Disable auto-merge** を押して予約を外してから作業してください。

### 緊急時（CI が壊れて merge できないなど）の対応

Bypass list を空にしているため、管理者（自分）もルールを迂回できません。
CI 自体が壊れていてどの PR も merge できないなど、どうしてもルールを外す必要があるときは、
**Settings** → **Rules** → **Rulesets** で `main` のルールセットを開き、**Enforcement status** を一時的に **Disabled** にして対応します。
対応が終わったら、**必ず Active に戻してください**。

### 自動マージを止めたいとき

- **特定の PR だけ止める:** PR の画面下部にある **Disable auto-merge** を押す
- **仕組み全体を止める:** **Actions** タブ → 左の一覧から **Dependabot auto-merge** を選び、右上の **…** メニューから **Disable workflow** を選ぶ
  （すでに予約済みの PR は、上の方法で個別に止める必要があります）
