---
paths:
  - "spec/**/*_spec.rb"
---

# RSpec の書き方

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
