require "rails_helper"

RSpec.describe "Places", type: :system do
  let(:user) { create(:user) }

  before do
    create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip)
    sign_in user
  end

  # 編集の流れは JavaScript を使わないため request spec で担保する。
  # ここでは Turbo の確認ダイアログ(JavaScript)を伴う削除だけを確認する。
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
