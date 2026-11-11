require "rails_helper"

RSpec.describe "Navbar", type: :system do
  let(:user) { create(:user, name: "力輝") }

  before do
    sign_in user
  end

  # ナビバーのユーザー名を押してドロップダウンを開く
  def open_user_menu
    within("nav.navbar") { click_button "力輝" }
  end

  # ハンバーガーメニューを開く（ボタンは aria-label しか持たないため、クラスで探して押す）
  def open_hamburger_menu
    find("nav.navbar button.navbar-toggler[aria-label='メニューを開く']").click
  end

  context "デスクトップ幅の場合" do
    before { visit root_path }

    it "ユーザー名を押すまで「アカウント設定」を表示しないこと" do
      expect(page).to have_no_link("アカウント設定")
    end

    it "ユーザー名 →「アカウント設定」でアカウント設定画面へ移動できること", :aggregate_failures do
      open_user_menu
      within("nav.navbar") { click_link "アカウント設定" }
      expect(page).to have_current_path(edit_user_registration_path)
      expect(page).to have_css("h1", text: "アカウント設定")
    end

    it "ユーザー名 →「ログアウト」でログアウトでき、ログイン画面に戻ること", :aggregate_failures do
      open_user_menu
      within("nav.navbar") { click_button "ログアウト" }
      expect(page).to have_content("ログアウトしました。")
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context "スマホ幅の場合" do
    # ウィンドウの大きさは次のテストにも引き継がれるため、変更前の大きさを覚えておき、終わったら戻す
    let!(:original_size) { page.current_window.size }

    before do
      page.current_window.resize_to(375, 812)
      visit root_path
    end

    after { page.current_window.resize_to(*original_size) }

    it "ハンバーガーメニューを開くまでユーザー名を表示しないこと" do
      expect(page).to have_no_button("力輝")
    end

    it "ハンバーガーメニュー → ユーザー名 →「アカウント設定」でアカウント設定画面へ移動できること", :aggregate_failures do
      open_hamburger_menu
      open_user_menu
      within("nav.navbar") { click_link "アカウント設定" }
      expect(page).to have_current_path(edit_user_registration_path)
      expect(page).to have_css("h1", text: "アカウント設定")
    end

    it "ハンバーガーメニュー →「訪問記録」で訪問記録の一覧へ移動できること" do
      open_hamburger_menu
      within("nav.navbar") { click_link "訪問記録" }
      expect(page).to have_current_path(visits_path)
    end

    it "ハンバーガーメニュー → ユーザー名 →「ログアウト」でログアウトできること", :aggregate_failures do
      open_hamburger_menu
      open_user_menu
      within("nav.navbar") { click_button "ログアウト" }
      expect(page).to have_content("ログアウトしました。")
      expect(page).to have_current_path(new_user_session_path)
    end
  end
end
