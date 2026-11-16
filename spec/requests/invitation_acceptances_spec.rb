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

      # Devise の authenticate_user! が開こうとした URL をセッションに覚え、ログイン後に戻す
      it "ログインすると確認画面に戻ること" do
        get invitation_acceptance_path(invitation.token)
        post user_session_path, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to(invitation_acceptance_path(invitation.token))
      end

      # サインアップ後も Devise は after_sign_in_path_for を使うため、同じく確認画面に戻る
      it "サインアップすると確認画面に戻ること" do
        get invitation_acceptance_path(invitation.token)
        post user_registration_path, params: {
          user: { name: "招待された人", email: "invited@example.com", password: "password123", password_confirmation: "password123" }
        }
        expect(response).to redirect_to(invitation_acceptance_path(invitation.token))
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

      # 参加できる人にだけ参加ボタン（このリンクへ POST するフォーム）を出す
      it "参加するボタンを表示すること" do
        expect(response.body).to include(%(action="#{invitation_acceptance_path(invitation.token)}"))
      end
    end

    context "ログイン済みで今のグループにほかのメンバーがいる場合" do
      before do
        create(:membership, group: user.group)
        sign_in user
        get invitation_acceptance_path(invitation.token)
      end

      it "参加できないことを表示し、参加するボタンを出さないこと", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("このグループには参加できません")
        expect(response.body).not_to include(%(action="#{invitation_acceptance_path(invitation.token)}"))
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

    # すでにメンバーかどうかの判定を、ほかのメンバーがいるかより先に行うこと
    context "ログイン済みで招待した人以外のメンバーが開いた場合" do
      # inviter 以外のメンバー。別の招待で inviter のグループに参加させる（このグループには自分以外のメンバーもいる）
      let(:member) { create(:user).tap { |m| create(:invitation, inviter: inviter).accept!(m) } }

      before do
        sign_in member
        get invitation_acceptance_path(invitation.token)
      end

      it "参加済みであることを表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("すでにこのグループに参加しています")
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

  describe "POST /invite/:token" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトし、リンクを使用済みにしないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to redirect_to(new_user_session_path)
        expect(invitation.reload.used_at).to be_nil
      end
    end

    context "ログイン済みで参加できる場合" do
      let!(:moved_place) { create(:place, group: user.group, name: "元のグループの場所") }
      let!(:inviter_place) { create(:place, group: inviter.group, name: "参加先の場所") }

      before { sign_in user }

      it "行きたい場所一覧へリダイレクトし、参加したことを表示すること", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to redirect_to(places_path)
        expect(response).to have_http_status(:see_other)
        follow_redirect!
        expect(response.body).to include("力輝さんのグループに参加しました")
      end

      # 参加後は User#group（groups.first）が参加先を返し、一覧に移った場所と参加先の場所の両方が出ること
      it "参加先のメンバーになり、一覧に両方のグループの場所が出ること", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(user.reload.group).to eq(invitation.group)
        follow_redirect!
        expect(response.body).to include(moved_place.name, inviter_place.name)
      end

      it "リンクが使用済みになること" do
        post invitation_acceptance_path(invitation.token)
        expect(invitation.reload.used_at).to be_present
      end
    end

    context "ログイン済みで使用済みのリンクの場合" do
      before do
        invitation.update!(used_at: 1.hour.ago)
        sign_in user
      end

      it "404 を返し、参加させないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include("このリンクは使えません")
        expect(user.reload.group).not_to eq(invitation.group)
      end
    end

    context "ログイン済みで期限切れのリンクの場合" do
      # travel_to は秒未満を切り捨てるため、有効期限も秒ちょうどにしておく
      let(:invitation) { create(:invitation, inviter: inviter, expires_at: 1.day.from_now.change(usec: 0)) }

      before { sign_in user }

      it "404 を返し、参加させないこと", :aggregate_failures do
        travel_to(invitation.expires_at) do
          post invitation_acceptance_path(invitation.token)
        end
        expect(response).to have_http_status(:not_found)
        expect(user.reload.group).not_to eq(invitation.group)
      end
    end

    context "ログイン済みで存在しないトークンの場合" do
      before { sign_in user }

      it "404 を返すこと" do
        post invitation_acceptance_path("unknown-token")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "ログイン済みですでにそのグループのメンバーの場合" do
      before { sign_in inviter }

      it "確認画面へ戻して参加済みを表示し、リンクを使用済みにしないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to redirect_to(invitation_acceptance_path(invitation.token))
        follow_redirect!
        expect(response.body).to include("すでにこのグループに参加しています")
        expect(invitation.reload.used_at).to be_nil
      end
    end

    # 招待した人以外のメンバーは、グループにほかのメンバーがいても「参加済み」になること（判定順）
    context "ログイン済みで招待した人以外のメンバーが参加しようとした場合" do
      let(:member) { create(:user).tap { |m| create(:invitation, inviter: inviter).accept!(m) } }

      before { sign_in member }

      it "確認画面へ戻して参加済みを表示し、リンクを使用済みにしないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to redirect_to(invitation_acceptance_path(invitation.token))
        follow_redirect!
        expect(response.body).to include("すでにこのグループに参加しています")
        expect(invitation.reload.used_at).to be_nil
      end
    end

    # 事前の判定は通ったが、参加処理でロックを取るまでの間に誰かが今のグループに参加した場合
    context "ログイン済みで参加処理の途中に今のグループへほかのメンバーが入った場合" do
      let!(:old_group) { user.group }

      before do
        # 同時に起きる競合を再現するため、accept! の本処理の直前に今のグループへメンバーを足す
        allow(Invitation).to receive(:find_by).and_return(invitation)
        allow(invitation).to receive(:accept!).and_wrap_original do |original, accepting_user|
          create(:membership, group: old_group)
          original.call(accepting_user)
        end
        sign_in user
      end

      it "422 で参加できないことを表示し、参加させないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("このグループには参加できません")
        expect(invitation.reload.used_at).to be_nil
        expect(user.reload.group).to eq(old_group)
      end
    end

    context "ログイン済みで今のグループにほかのメンバーがいる場合" do
      let!(:old_group) { user.group }

      before do
        create(:membership, group: old_group)
        sign_in user
      end

      it "422 で参加できないことを表示し、参加させないこと", :aggregate_failures do
        post invitation_acceptance_path(invitation.token)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("このグループには参加できません")
        expect(invitation.reload.used_at).to be_nil
        expect(user.reload.group).to eq(old_group)
      end
    end
  end
end
