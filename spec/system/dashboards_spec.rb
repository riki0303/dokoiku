require "rails_helper"

RSpec.describe "Dashboards", type: :system do
  let(:user) { create(:user, name: "山田太郎") }

  context "未ログインの場合" do
    before { visit root_path }

    it "ログイン画面が表示されること" do
      expect(page).to have_current_path(new_user_session_path)
    end

    context "ログイン画面からログインした場合" do
      before do
        fill_in "user[email]", with: user.email
        fill_in "user[password]", with: "password123"
        click_button I18n.t("devise.sessions.new.sign_in")
      end

      it "ユーザー名入りのダッシュボードを表示すること", :aggregate_failures do
        expect(page).to have_content("ようこそ、山田太郎さん")
        expect(page).to have_current_path(root_path)
      end
    end
  end

  context "ログイン済みの場合" do
    before { sign_in user }

    it "ユーザー名入りのダッシュボードを表示すること" do
      visit root_path
      expect(page).to have_content("ようこそ、山田太郎さん")
    end
  end
end
