require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let!(:user) { create(:user, email: "taro@example.com", password: "password123") }

  describe "GET /users/sign_in" do
    it "renders the sign in form", :aggregate_failures do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("パスワードを忘れましたか？")
    end
  end

  describe "POST /users/sign_in" do
    it "signs in with the correct password and redirects to root", :aggregate_failures do
      post user_session_path, params: { user: { email: "taro@example.com", password: "password123" } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("ようこそ、#{user.name}さん")
    end

    it "fails with a wrong password", :aggregate_failures do
      post user_session_path, params: { user: { email: "taro@example.com", password: "wrong-password" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("メールアドレスまたはパスワードが違います。")
    end
  end

  describe "DELETE /users/sign_out" do
    before { sign_in user }

    it "redirects to the sign in page with a notice", :aggregate_failures do
      delete destroy_user_session_path
      expect(response).to redirect_to(new_user_session_path)

      follow_redirect!
      expect(response.body).to include("ログアウトしました。")
    end

    it "destroys the session" do
      delete destroy_user_session_path
      get root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
