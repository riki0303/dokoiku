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

    it "確認ダイアログで OK すると、場所が消えること", :aggregate_failures do
      accept_confirm("江ノ島を削除しますか？") { click_button "削除する" }

      # 削除後の画面に切り替わるのを待ってから DB を確かめる
      expect(page).to have_content("江ノ島を削除しました")
      expect(Place.exists?(name: "江ノ島")).to be(false)
    end

    context "名前を空白だけにして更新に失敗したあとの場合" do
      before do
        # 空白だけならブラウザの入力チェック（required）を通り、サーバー側のバリデーションで失敗する
        fill_in "place[name]", with: " "
        click_button "更新する"
        # 更新に失敗した編集フォームが再表示されるのを待つ
        assert_text "を入力してください"
      end

      it "確認ダイアログに未保存の名前ではなく DB 上の名前を出し、OK すると場所が消えること", :aggregate_failures do
        accept_confirm("江ノ島を削除しますか？") { click_button "削除する" }

        expect(page).to have_content("江ノ島を削除しました")
        expect(Place.exists?(name: "江ノ島")).to be(false)
      end
    end
  end
end
