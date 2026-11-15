require "rails_helper"

RSpec.describe "Invitations", type: :request do
  let(:user) { create(:user) }

  describe "GET /invitations/new" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get new_invitation_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "発行画面を表示すること", :aggregate_failures do
        get new_invitation_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("招待リンクを発行する")
      end

      it "開いただけでは招待を作らないこと" do
        expect { get new_invitation_path }.not_to change(Invitation, :count)
      end
    end
  end

  describe "POST /invitations" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトし、招待を作らないこと", :aggregate_failures do
        expect { post invitations_path }.not_to change(Invitation, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "自分のグループへの招待を作ること", :aggregate_failures do
        expect { post invitations_path }.to change(Invitation, :count).by(1)
        expect(Invitation.last).to have_attributes(group: user.group, inviter: user, used_at: nil)
      end

      it "303 で発行した招待の画面にリダイレクトすること", :aggregate_failures do
        post invitations_path
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(invitation_path(Invitation.last))
      end
    end
  end

  describe "GET /invitations/:id" do
    # 日本時間で表示していることを確かめるため、有効期限は UTC で日付がずれる固定の時刻にする
    let(:invitation) { create(:invitation, inviter: user, expires_at: Time.utc(2026, 11, 18, 0, 5)) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get invitation_path(invitation)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before do
        sign_in user
        get invitation_path(invitation)
      end

      it "トークン入りの招待リンクを表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.at_css("input[readonly]")["value"]).to eq(invitation_acceptance_url(invitation.token))
      end

      it "有効期限を日本時間で表示すること" do
        expect(response.body).to include("2026/11/18 09:05")
      end
    end
  end
end
