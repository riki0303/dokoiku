require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  describe "GET /" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      let(:user) { create(:user, name: "山田太郎") }

      before { sign_in user }

      it "ユーザー名入りのダッシュボードを表示すること", :aggregate_failures do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ようこそ、山田太郎さん")
      end
    end
  end
end
