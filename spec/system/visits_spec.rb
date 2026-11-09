require "rails_helper"

RSpec.describe "Visits", type: :system do
  let(:user) { create(:user) }

  before do
    place = create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip)
    create(:visit, place: place, want_again: false)
    sign_in user
  end

  # 記録の流れは JavaScript を使わないため request spec で担保する。
  # ここでは Turbo の確認ダイアログ(JavaScript)を伴う取り消しだけを確認する。
  describe "取り消し" do
    before { visit visits_path }

    it "確認ダイアログでキャンセルすると、記録が残ること", :aggregate_failures do
      dismiss_confirm("江ノ島の訪問記録を取り消しますか？") { click_button "取り消す" }

      expect(page).to have_current_path(visits_path)
      expect(page).to have_css(".list-group-item", text: "江ノ島")
      expect(Visit.count).to eq(1)
    end

    it "確認ダイアログで OK すると、完了メッセージ付きで訪問記録の一覧に戻り、行きたい場所に戻ること", :aggregate_failures do
      accept_confirm("江ノ島の訪問記録を取り消しますか？") { click_button "取り消す" }

      expect(page).to have_content("江ノ島の訪問記録を取り消しました")
      expect(page).to have_current_path(visits_path)
      expect(page).to have_content("まだ訪問した場所はありません")
      expect(Place.wanted.pluck(:name)).to eq(%w[江ノ島])
    end
  end
end
