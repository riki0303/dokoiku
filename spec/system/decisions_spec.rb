require "rails_helper"

RSpec.describe "Decisions", type: :system do
  let(:user) { create(:user) }

  # 画面に出ている場所の名前
  def shown_names
    all(".card-title").map(&:text)
  end

  # 絞り込みボタンを押し、選んだ距離感の画面に入れ替わるまで待つ（次の操作や確認を前の画面に対して行わないため）
  def click_distance(label)
    click_link label
    find("a[aria-current='page']", text: label)
  end

  context "未ログインの場合" do
    before do
      create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい")
      visit root_path
    end

    it "ログイン画面が表示されること" do
      expect(page).to have_current_path(new_user_session_path)
    end

    context "ログイン画面からログインした場合" do
      before do
        fill_in "user[email]", with: user.email
        fill_in "user[password]", with: "password123"
        click_button I18n.t("devise.sessions.new.sign_in")
      end

      it "トップに今日決める画面が表示されること", :aggregate_failures do
        expect(page).to have_current_path(root_path)
        expect(page).to have_css(".card", text: "夕日を見に行きたい")
      end
    end
  end

  context "ログイン済みの場合" do
    before do
      %w[公園 カフェ 図書館 美術館 温泉].each { |name| create(:place, group: user.group, name: name) }
      sign_in user
      visit root_path
    end

    it "「別の3件」を押すと、まだ出ていない場所に入れ替わること", :aggregate_failures do
      first = all(".card-title", count: 3).map(&:text)
      click_button "別の3件"
      expect(page).to have_css(".card", count: 2)
      expect(shown_names).not_to include(*first)
    end

    it "「別の3件」のあとに再読み込みしても、同じ場所を表示すること" do
      click_button "別の3件"
      second = all(".card-title", count: 2).map(&:text)
      refresh
      expect(page).to have_css(".card-title", count: 2) { |title| second.include?(title.text) }
    end

    it "「別の3件」を押し続けて引き切ると、候補がない旨と登録画面へのリンクを表示すること", :aggregate_failures do
      click_button "別の3件"
      # 2回目を押す前に、1回目の画面の入れ替わりを待つ
      all(".card", count: 2)
      click_button "別の3件"
      expect(page).to have_content("今日はもう候補がありません")
      expect(page).to have_link("場所を登録する", href: new_place_path)
    end

    it "絞り込みボタンで「すべて → 近場 → すべて」と切り替えると、同じ場所に戻ること" do
      first = all(".card-title", count: 3).map(&:text)
      click_distance "近場"
      click_distance "すべて"
      expect(shown_names).to eq(first)
    end

    it "ナビバーから場所の登録画面へ移動できること" do
      within("nav.navbar") { click_link "場所を登録" }
      expect(page).to have_current_path(new_place_path)
    end

    it "ナビバーからストック一覧へ移動できること" do
      within("nav.navbar") { click_link "ストック一覧" }
      expect(page).to have_current_path(places_path)
    end
  end
end
