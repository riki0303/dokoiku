require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      skip_authorization
      render plain: current_group&.id.to_s
    end
  end

  describe "#current_group" do
    context "ログイン済みの場合" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "ログイン中ユーザーのグループを返すこと", :aggregate_failures do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(user.group.id.to_s)
      end

      it "ビューから参照できるよう helper_method として公開されていること" do
        expect(controller.view_context).to respond_to(:current_group)
      end
    end
  end
end
