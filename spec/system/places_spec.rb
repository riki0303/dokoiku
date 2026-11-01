require "rails_helper"

RSpec.describe "Places", type: :system do
  let(:user) { create(:user) }

  before do
    create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip)
    sign_in user
  end

  describe "編集" do
    before do
      visit places_path
      click_link "編集"
    end

    it "一覧の「編集」から、今の値が入った編集画面を開けること" do
      expect(page).to have_field("place[name]", with: "江ノ島")
    end

    context "値を変えて更新した場合" do
      before do
        fill_in "place[name]", with: "鎌倉"
        fill_in "place[note]", with: "大仏を見たい"
        choose "遠出"
        click_button "更新する"
      end

      it "完了メッセージ付きで一覧に戻り、変更後の内容が出ること", :aggregate_failures do
        expect(page).to have_content("鎌倉を更新しました")
        expect(page).to have_current_path(places_path)
        expect(page).to have_css(".list-group-item", text: "大仏を見たい")
        expect(page).to have_no_content("江ノ島")
      end
    end
  end

  describe "削除" do
    before { visit edit_place_path(Place.find_by!(name: "江ノ島")) }

    it "確認ダイアログでキャンセルすると、場所が残ること", :aggregate_failures do
      dismiss_confirm("江ノ島を削除しますか？") { click_button "削除する" }

      expect(page).to have_current_path(%r{/places/\d+/edit})
      expect(Place.exists?(name: "江ノ島")).to be(true)
    end

    it "確認ダイアログで OK すると、完了メッセージ付きで一覧に戻り、場所が消えること", :aggregate_failures do
      accept_confirm("江ノ島を削除しますか？") { click_button "削除する" }

      expect(page).to have_content("江ノ島を削除しました")
      expect(page).to have_current_path(places_path)
      expect(page).to have_no_css(".list-group-item", text: "江ノ島")
      expect(Place.exists?(name: "江ノ島")).to be(false)
    end
  end
end
