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

      it "DB には文字列で保存されること" do
        place = create(:place, distance: :day_trip)
        expect(place.distance_before_type_cast).to eq("day_trip")
      end
    end
  end
end
