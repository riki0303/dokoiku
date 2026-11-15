require "rails_helper"

RSpec.describe "InvitationAcceptances", type: :request do
  let(:inviter) { create(:user, name: "力輝") }
  let(:invitation) { create(:invitation, inviter: inviter) }
  let(:user) { create(:user) }

  describe "GET /invite/:token" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get invitation_acceptance_path(invitation.token)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで有効なリンクの場合" do
      before do
        create_list(:place, 2, group: user.group)
        # 消化済みの場所も参加先へ移るため件数に含める
        create(:visit, place: create(:place, group: user.group), want_again: false)
        # 招待した側のグループの場所は数えない
        create(:place, group: inviter.group)
        sign_in user
        get invitation_acceptance_path(invitation.token)
      end

      it "招待した人の名前と、今のグループの場所の件数（消化済みを含む）を表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("力輝さんのグループに参加しますか？", "今のグループの場所（3件）")
      end

      it "開いただけではリンクを使用済みにしないこと" do
        expect(invitation.reload.used_at).to be_nil
      end
    end

    context "ログイン済みで使用済みのリンクの場合" do
      before do
        invitation.update!(used_at: 1.hour.ago)
        sign_in user
      end

      it "404 を返し、使えないことを表示すること", :aggregate_failures do
        get invitation_acceptance_path(invitation.token)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
      end
    end

    context "ログイン済みで期限切れのリンクの場合" do
      # travel_to は秒未満を切り捨てるため、有効期限も秒ちょうどにしておく
      let(:invitation) { create(:invitation, inviter: inviter, expires_at: 1.day.from_now.change(usec: 0)) }

      before { sign_in user }

      it "404 を返し、使えないことを表示すること", :aggregate_failures do
        travel_to(invitation.expires_at) do
          get invitation_acceptance_path(invitation.token)
        end
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
      end
    end

    context "ログイン済みで存在しないトークンの場合" do
      before { sign_in user }

      it "404 を返し、使えないことを表示すること", :aggregate_failures do
        get invitation_acceptance_path("unknown-token")
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
      end
    end

    context "ログイン済みですでにそのグループのメンバーの場合" do
      before do
        sign_in inviter
        get invitation_acceptance_path(invitation.token)
      end

      it "参加済みであることを表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("すでにこのグループに参加しています")
      end

      it "リンクを使用済みにしないこと" do
        expect(invitation.reload.used_at).to be_nil
      end
    end

    # 使えるかどうかの判定を、メンバーかどうかより先に行うこと
    context "ログイン済みですでにそのグループのメンバーが使用済みのリンクを開いた場合" do
      before do
        invitation.update!(used_at: 1.hour.ago)
        sign_in inviter
      end

      it "404 を返し、使えないことを表示すること", :aggregate_failures do
        get invitation_acceptance_path(invitation.token)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
      end
    end

    context "ログイン済みですでにそのグループのメンバーが期限切れのリンクを開いた場合" do
      # travel_to は秒未満を切り捨てるため、有効期限も秒ちょうどにしておく
      let(:invitation) { create(:invitation, inviter: inviter, expires_at: 1.day.from_now.change(usec: 0)) }

      before { sign_in inviter }

      it "404 を返し、使えないことを表示すること", :aggregate_failures do
        travel_to(invitation.expires_at) do
          get invitation_acceptance_path(invitation.token)
        end
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
      end
    end
  end
end
