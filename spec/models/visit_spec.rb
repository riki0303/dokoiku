require "rails_helper"

RSpec.describe Visit, type: :model do
  describe "バリデーション" do
    subject(:visit) { build(:visit) }

    it "正しい属性なら有効であること" do
      expect(visit).to be_valid
    end

    describe "visited_on" do
      it "必須で、エラーが1件だけ出ること", :aggregate_failures do
        visit.visited_on = nil
        expect(visit).not_to be_valid
        expect(visit.errors[:visited_on]).to eq([ "を入力してください" ])
      end

      it "明日なら無効であること", :aggregate_failures do
        visit.visited_on = Date.current.tomorrow
        expect(visit).not_to be_valid
        expect(visit.errors.full_messages).to include("訪問日は今日以前の日付を入力してください")
      end

      it "今日なら有効であること" do
        visit.visited_on = Date.current
        expect(visit).to be_valid
      end

      it "過去の日付なら有効であること" do
        visit.visited_on = 1.year.ago.to_date
        expect(visit).to be_valid
      end
    end

    describe "want_again" do
      it "nil なら無効であること", :aggregate_failures do
        visit.want_again = nil
        expect(visit).not_to be_valid
        expect(visit.errors.full_messages).to include("また行きたいかを選択してください")
      end

      it "false（いいえ）なら有効であること" do
        visit.want_again = false
        expect(visit).to be_valid
      end

      it "true（はい）なら有効であること" do
        visit.want_again = true
        expect(visit).to be_valid
      end
    end
  end

  it "同じ場所に複数件記録できること" do
    place = create(:place)
    create(:visit, place: place, want_again: true, visited_on: 1.month.ago.to_date)
    expect { create(:visit, place: place, want_again: true) }.to change(place.visits, :count).by(1)
  end
end
