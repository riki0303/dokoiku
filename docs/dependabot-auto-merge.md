# Dependabot 自動マージとブランチ保護の設定手順

Dependabot のパッチ・マイナー更新 PR を、CI がすべて成功したあとに自動で merge するための設定手順です（Issue #86）。

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
4. GitHub が、ルールセットで必須にした CI の 6 ジョブがすべて成功するのを待ってから merge します

| PR の種類 | どうなるか |
| --- | --- |
| Dependabot のパッチ・マイナー更新 | 自動マージが予約され、CI 成功後に merge される |
| Dependabot のパッチ・マイナー更新で CI が失敗 | merge されずに残る（手で確認する） |
| Dependabot のメジャー更新 | 予約されない（今まで通り手でレビューして merge） |
| 更新の種類が判定できない PR（バージョンを比較できない更新。git 参照の gem、SHA 固定の action など） | 予約されない（安全側に倒している） |
| 人が作った PR | ワークフロー自体が動かない（対象外） |

- 対象の依存は bundler / github-actions / npm（セキュリティ更新）のすべてです。ecosystem では絞っていません
- 承認（Approve）は不要です。ルールセットの必須承認数を 0 にしているためです

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
- **Require status checks to pass**（CI の成功を必須にする）
  - **Require branches to be up to date before merging**: **OFF**（チェックを外す）
  - **Add checks** で次の 6 つを追加する
    - `brakeman`
    - `bundler_audit`
    - `importmap_audit`
    - `rubocop`
    - `rails_best_practices`
    - `rspec`
- **Block force pushes**（force push を禁止）

最後に **Create** を押して保存します。

**「Require branches to be up to date before merging」を OFF にする理由:**
ON にすると、PR のブランチが最新の `main` を取り込んでいないと merge できなくなります。
Dependabot の PR が何件も溜まっているとき、1 件 merge するたびに残りの PR がすべて rebase 待ちになり、
自動マージが順番に詰まってしまうため OFF にします。

**必須チェック名について:**
必須チェックの名前は `.github/workflows/ci.yml` の **ジョブ名**（`jobs:` の直下のキー）と一致している必要があります。
`ci.yml` のジョブ名を変更したり、ジョブを追加・削除したりした場合は、**ルールセットの必須チェックも合わせて更新してください**。
更新しないと、存在しないチェックを待ち続けて PR が merge できなくなります。

---

## 4. 設定後の確認

- 人の PR で、CI が完了する前・失敗したときに merge ボタンが押せないこと
- `main` へ直接 push すると拒否されること
- Dependabot のパッチ・マイナー更新 PR に「Auto-merge enabled」と表示され、CI 成功後に merge されること

### 確認事項: github-actions の更新 PR が自動 merge まで進むか

github-actions の更新 PR は `.github/workflows/` 配下のファイルを変更します。
`GITHUB_TOKEN` で予約した自動 merge がこの種の PR でも通るかは **未確認** です。
最初に届いた github-actions の更新 PR で、CI 成功後に実際に merge まで進むかを確認してください。
merge されずに止まった場合は、手で merge してください。

---

## 5. 注意点

### 自動マージで merge されたあと、`main` の CI は動かない

ワークフローの `GITHUB_TOKEN` で行った操作は、GitHub の仕様で他のワークフローを起動しません。
そのため、自動マージによる `main` への push では `ci.yml` の `push: main` トリガーが動きません。
merge 前に PR 上で CI が通っており、デプロイ用のワークフローもないため、問題にならない想定です。

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
