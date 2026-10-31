require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "新規登録フォームを表示すること" do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    let(:params) do
      {
        user: {
          name: "山田太郎",
          email: "taro@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    context "パラメータが正しい場合" do
      it "ユーザーを作成すること" do
        expect { post user_registration_path, params: params }.to change(User, :count).by(1)
      end

      it "名前を保存してトップページにリダイレクトすること", :aggregate_failures do
        post user_registration_path, params: params
        expect(User.last.name).to eq("山田太郎")
        expect(response).to redirect_to(root_path)
      end
    end

    context "パスワードが8文字未満の場合" do
      before do
        params[:user][:password] = "a" * 7
        params[:user][:password_confirmation] = "a" * 7
      end

      it "ユーザーを作成しないこと" do
        expect { post user_registration_path, params: params }.not_to change(User, :count)
      end

      it "エラーを表示してフォームを再表示すること", :aggregate_failures do
        post user_registration_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("パスワードは8文字以上で入力してください")
      end
    end

    context "名前が空の場合" do
      before { params[:user][:name] = "" }

      it "ユーザーを作成しないこと" do
        expect { post user_registration_path, params: params }.not_to change(User, :count)
      end

      it "エラーを表示してフォームを再表示すること", :aggregate_failures do
        post user_registration_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("名前を入力してください")
      end
    end
  end

  describe "GET /users/edit" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get edit_user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in create(:user) }

      it "アカウント削除ボタン付きの編集フォームを表示すること", :aggregate_failures do
        get edit_user_registration_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("アカウント削除")
      end
    end
  end

  describe "PUT /users" do
    let(:user) { create(:user, name: "旧名前") }

    before { sign_in user }

    it "現在のパスワードを入力すると名前を更新すること", :aggregate_failures do
      put user_registration_path, params: { user: { name: "新名前", current_password: "password123" } }
      expect(user.reload.name).to eq("新名前")
      expect(response).to redirect_to(root_path)
    end

    it "現在のパスワードがないと更新しないこと", :aggregate_failures do
      put user_registration_path, params: { user: { name: "新名前" } }
      expect(user.reload.name).to eq("旧名前")
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /users" do
    let!(:user) { create(:user) }

    context "ログイン済みの場合" do
      before { sign_in user }

      it "ユーザーを削除すること" do
        expect { delete user_registration_path }.to change(User, :count).by(-1)
      end

      it "ログインページにリダイレクトすること" do
        delete user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "未ログインの場合" do
      it "ユーザーを削除しないこと" do
        expect { delete user_registration_path }.not_to change(User, :count)
      end

      it "ログインページにリダイレクトすること" do
        delete user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
