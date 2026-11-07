require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let!(:user) { create(:user, email: "taro@example.com", password: "password123") }

  describe "GET /users/sign_in" do
    it "ログインフォームを表示すること", :aggregate_failures do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("パスワードを忘れましたか？")
    end

    it "未ログインのナビバーに「今日どこ行く？」と場所一覧へのリンクを表示しないこと" do
      get new_user_session_path
      expect(response.parsed_body.css("nav.navbar a").map(&:text)).not_to include("今日どこ行く？", "場所一覧")
    end

    # request spec ではブラウザの入力チェックは動かないため、HTML5 の属性が出力されていることを確認する
    it "novalidate を付けず、メールアドレスとパスワードに required を付けること", :aggregate_failures do
      get new_user_session_path
      form = response.parsed_body.at_css("form#new_user")
      expect(form["novalidate"]).to be_nil
      expect(form.at_css("input[name='user[email]']")["required"]).to eq("required")
      expect(form.at_css("input[name='user[password]']")["required"]).to eq("required")
    end
  end

  describe "POST /users/sign_in" do
    it "正しいパスワードでログインしてトップページにリダイレクトすること", :aggregate_failures do
      post user_session_path, params: { user: { email: "taro@example.com", password: "password123" } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.parsed_body.at_css("h1")&.text).to eq("今日どこ行く？")
    end

    it "パスワードが間違っているとログインに失敗すること", :aggregate_failures do
      post user_session_path, params: { user: { email: "taro@example.com", password: "wrong-password" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("メールアドレスまたはパスワードが違います。")
    end
  end

  describe "DELETE /users/sign_out" do
    before { sign_in user }

    it "ログインページにリダイレクトしてお知らせを表示すること", :aggregate_failures do
      delete destroy_user_session_path
      expect(response).to redirect_to(new_user_session_path)

      follow_redirect!
      expect(response.body).to include("ログアウトしました。")
    end

    it "セッションを破棄すること" do
      delete destroy_user_session_path
      get root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
