require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "redirects to the sign in page" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user, name: "山田太郎") }

      before { sign_in user }

      it "shows the dashboard with the user's name", :aggregate_failures do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ようこそ、山田太郎さん")
      end
    end
  end
end
