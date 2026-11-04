require "rails_helper"

RSpec.describe Place, type: :model do
  describe "バリデーション" do
    subject(:place) { build(:place) }

    it "正しい属性なら有効であること" do
      expect(place).to be_valid
    end

    describe "name" do
      it "必須であること", :aggregate_failures do
        place.name = ""
        expect(place).not_to be_valid
        expect(place.errors[:name]).to include("を入力してください")
      end

      it "100文字なら有効であること" do
        place.name = "あ" * 100
        expect(place).to be_valid
      end

      it "101文字なら無効であること", :aggregate_failures do
        place.name = "あ" * 101
        expect(place).not_to be_valid
        expect(place.errors[:name]).to include("は100文字以内で入力してください")
      end
    end

    describe "note" do
      it "必須であること", :aggregate_failures do
        place.note = ""
        expect(place).not_to be_valid
        expect(place.errors[:note]).to include("を入力してください")
      end

      it "200文字なら有効であること" do
        place.note = "あ" * 200
        expect(place).to be_valid
      end

      it "201文字なら無効であること", :aggregate_failures do
        place.note = "あ" * 201
        expect(place).not_to be_valid
        expect(place.errors[:note]).to include("は200文字以内で入力してください")
      end
    end

    describe "distance" do
      [ nil, "" ].each do |value|
        it "#{value.inspect} なら必須エラーが1件だけ出ること", :aggregate_failures do
          place.distance = value
          expect(place).not_to be_valid
          expect(place.errors[:distance]).to eq([ "を入力してください" ])
        end
      end

      it "一覧にない値なら無効で、エラーが1件だけ出ること", :aggregate_failures do
        place.distance = "xxx"
        expect(place).not_to be_valid
        expect(place.errors[:distance]).to eq([ "は一覧にありません" ])
      end

      %w[near day_trip far].each do |value|
        it "#{value} なら有効であること" do
          place.distance = value
          expect(place).to be_valid
        end
      end

      it "DB には文字列で保存されること" do
        place = create(:place, distance: :day_trip)
        expect(place.distance_before_type_cast).to eq("day_trip")
      end
    end
  end

  describe "ransack の許可リスト" do
    it "検索できる項目は distance だけであること" do
      expect(described_class.ransackable_attributes).to eq(%w[distance])
    end

    it "関連の検索を許可しないこと（ApplicationRecord の既定）" do
      expect(described_class.ransackable_associations).to be_empty
    end

    it "並び替えを許可しないこと" do
      expect(described_class.ransortable_attributes).to be_empty
    end
  end

  describe "訪問記録" do
    it "場所を削除すると訪問記録も消えること" do
      place = create(:place)
      create_list(:visit, 2, place: place, want_again: true)
      expect { place.destroy }.to change(Visit, :count).by(-2)
    end
  end

  describe ".in_stock" do
    let!(:not_visited) { create(:place, name: "まだ行っていない") }
    let!(:want_again) { create(:place, name: "また行きたい") }
    let!(:done) { create(:place, name: "もう行かない") }
    let!(:changed_mind) { create(:place, name: "2回目でもういい") }

    before do
      create(:visit, place: want_again, want_again: true)
      create(:visit, place: done, want_again: false)
      create(:visit, place: changed_mind, want_again: true, visited_on: 1.month.ago.to_date)
      create(:visit, place: changed_mind, want_again: false)
    end

    it "訪問記録がない場所と「はい」の記録しかない場所を含むこと" do
      expect(described_class.in_stock).to contain_exactly(not_visited, want_again)
    end

    it "「いいえ」の記録が1件でもある場所を含まないこと" do
      expect(described_class.in_stock).not_to include(done, changed_mind)
    end
  end
end
