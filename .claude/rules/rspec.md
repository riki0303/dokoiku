---
paths:
  - "spec/**/*_spec.rb"
---

# RSpec の書き方

## spec の種類ごとの役割分担

同じことを複数の種類の spec で確かめない。下の表で「書くこと」に当たる spec にだけ書く。

| 種類 | 書くこと | 書かないこと |
|---|---|---|
| model spec | バリデーション、関連、モデルのメソッド | — |
| policy spec | ポリシーに書いた認可のロジック（誰が何をできるか）。認可はここだけで確かめる | — |
| request spec | ステータスコード、リダイレクト先、未ログイン時のリダイレクト（Devise の認証）、表示テキストの有無（`response.body` に文言が含まれるか） | 認可のパターン、CSS クラスや HTML 属性 |
| system spec | JS が絡む挙動（Turbo の確認ダイアログ `data-turbo-confirm`、Stimulus など） | 簡単な文言の確認、JS が絡まない画面の流れ |

### request spec で認可のパターンを書かない理由
- 認可のロジックは policy spec で確かめている
- `ApplicationController` の `after_action :verify_authorized` により、`authorize` を呼び忘れたアクションはテストの実行時にエラーになる
- 一覧に出す範囲（Scope）も policy spec の `describe "Scope"` で確かめる。`policy_scope` の呼び忘れは `verify_authorized` では検出されないので、コントローラーで `policy_scope` を使っていることはコードレビューで確認する
- 認可エラーを 404（`ActiveRecord::RecordNotFound`）に変える `ApplicationController` の処理も request spec では確かめない。誰が何をできるかの判定はポリシーにあるので、policy spec で確かめれば足りる

### request spec で CSS クラスや HTML 属性を確かめない理由
- 見た目のクラスはデザインを変えるたびにテストが壊れるため。確かめるのは表示されるテキストの有無までにする
- `data-turbo-confirm` などの属性は JS が動いて初めて意味を持つので、その挙動は system spec で確かめる

### system spec を JS が絡む挙動に限る理由
- system spec は headless Chrome で動くので遅く、不安定に落ちることもある。JS が要らない確認は request spec で足りる

### 迷いやすいケース
- 一覧が0件のときの「場所がありません」の表示 → request spec（`response.body` に含まれるか）
- 他グループの場所を編集できないこと → policy spec のみ（request spec には書かない）
- 削除ボタンの確認ダイアログで OK を押すと削除が実行されること（確認ダイアログの動き） → system spec（`accept_confirm` を使う）。レコードが消えることやリダイレクト先は request spec の DELETE で確かめる

## 説明文の書き方

- `describe` / `context` / `it` の説明文は日本語で書く
  - `describe` に書くクラス名・メソッド名・属性名・HTTP メソッドとパス（例: `"GET /users/sign_up"`）はそのままでよい
  - `context` は「〜の場合」「〜のとき」で書く
  - `it` は期待する振る舞いを「〜すること」「〜であること」のように「〜こと」で終える

```ruby
RSpec.describe "Users::Registrations", type: :request do
  describe "GET /users/sign_up" do
    context "未ログインの場合" do
      it "新規登録フォームを表示すること" do
        # ...
      end
    end
  end
end
```
