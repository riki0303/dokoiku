require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "renders the sign up form" do
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

    context "with valid params" do
      it "creates a user" do
        expect { post user_registration_path, params: params }.to change(User, :count).by(1)
      end

      it "saves the name and redirects to root", :aggregate_failures do
        post user_registration_path, params: params
        expect(User.last.name).to eq("山田太郎")
        expect(response).to redirect_to(root_path)
      end
    end

    context "with a password shorter than 8 characters" do
      before do
        params[:user][:password] = "a" * 7
        params[:user][:password_confirmation] = "a" * 7
      end

      it "does not create a user" do
        expect { post user_registration_path, params: params }.not_to change(User, :count)
      end

      it "re-renders the form with an error", :aggregate_failures do
        post user_registration_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("パスワードは8文字以上で入力してください")
      end
    end

    context "with a blank name" do
      before { params[:user][:name] = "" }

      it "does not create a user" do
        expect { post user_registration_path, params: params }.not_to change(User, :count)
      end

      it "re-renders the form with an error", :aggregate_failures do
        post user_registration_path, params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("名前を入力してください")
      end
    end
  end

  describe "GET /users/edit" do
    context "when not signed in" do
      it "redirects to the sign in page" do
        get edit_user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PUT /users" do
    let(:user) { create(:user, name: "旧名前") }

    before { sign_in user }

    it "updates the name with the current password", :aggregate_failures do
      put user_registration_path, params: { user: { name: "新名前", current_password: "password123" } }
      expect(user.reload.name).to eq("新名前")
      expect(response).to redirect_to(root_path)
    end

    it "does not update without the current password", :aggregate_failures do
      put user_registration_path, params: { user: { name: "新名前" } }
      expect(user.reload.name).to eq("旧名前")
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
