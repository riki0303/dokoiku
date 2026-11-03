require "rails_helper"

RSpec.describe TodayDeck do
  let(:group) { create(:group) }
  let(:scope) { Place.where(group: group) }
  let(:today) { Date.new(2026, 11, 2) }

  # セッションと同じく、前回の状態（Hash）を渡して作り直す
  def deck_from(state, on: today)
    described_class.new(state, scope, today: on)
  end

  describe "#hand" do
    context "場所が3件より多い場合" do
      before { create_list(:place, 5, group: group) }

      it "自分のグループの場所から3件を引くこと", :aggregate_failures do
        create(:place, group: create(:group))
        ids = deck_from(nil).hand(nil)
        expect(ids.size).to eq(3)
        expect(ids).to all(be_in(scope.ids))
      end

      it "同じ距離感でもう一度呼ぶと、同じ手札を返し山札を増やさないこと", :aggregate_failures do
        first = deck_from(nil)
        ids = first.hand(nil)
        second = deck_from(first.to_h)
        expect(second.hand(nil)).to eq(ids)
        expect(second.to_h["seen_ids"]).to match_array(ids)
      end

      it "距離感が違うと、新しく引き直すこと" do
        first = deck_from(nil)
        ids = first.hand(nil)
        expect(deck_from(first.to_h).hand("near")).not_to include(*ids)
      end
    end

    context "引き切ったあとに場所が増えた場合" do
      before { create_list(:place, 2, group: group) }

      it "同じ距離感でも、増えた場所を引くこと" do
        deck = deck_from(nil)
        deck.hand(nil)
        deck.draw(nil)
        added = create(:place, group: group)
        expect(deck_from(deck.to_h).hand(nil)).to eq([ added.id ])
      end
    end

    context "手札の場所がすべて削除された場合" do
      before { create_list(:place, 5, group: group) }

      it "まだ出していない場所から引き直すこと" do
        deck = deck_from(nil)
        first = deck.hand(nil)
        Place.where(id: first).destroy_all
        expect(deck_from(deck.to_h).hand(nil)).to match_array(scope.ids)
      end
    end

    it "手札の一部が削除された場合、残りの手札だけを返すこと" do
      create_list(:place, 5, group: group)
      deck = deck_from(nil)
      first = deck.hand(nil)
      Place.destroy(first.first)
      expect(deck_from(deck.to_h).hand(nil)).to eq(first.drop(1))
    end

    context "場所が3件未満の場合" do
      before { create_list(:place, 2, group: group) }

      it "ある分だけ引くこと" do
        expect(deck_from(nil).hand(nil)).to match_array(scope.ids)
      end
    end

    context "距離感を指定した場合" do
      before do
        create_list(:place, 2, group: group, distance: :near)
        create_list(:place, 2, group: group, distance: :far)
      end

      it "その距離感の場所だけを引くこと" do
        expect(deck_from(nil).hand("far")).to match_array(scope.far.ids)
      end

      it "距離感を切り替えても山札は共通で、一度出した場所は出さないこと" do
        deck = deck_from(nil)
        deck.hand("near")
        expect(deck_from(deck.to_h).hand(nil)).to match_array(scope.far.ids)
      end
    end

    context "日付が変わった場合" do
      before { create_list(:place, 3, group: group) }

      it "山札をリセットし、同じ場所をまた引けること", :aggregate_failures do
        yesterday = deck_from(nil, on: today - 1)
        yesterday.hand(nil)
        deck = deck_from(yesterday.to_h)
        expect(deck.hand(nil)).to match_array(scope.ids)
        expect(deck.to_h["date"]).to eq(today.iso8601)
      end
    end

    context "セッションのキーが文字列の場合（Cookie を経由した場合）" do
      before { create_list(:place, 4, group: group) }

      it "同じ手札を返すこと" do
        first = deck_from(nil)
        ids = first.hand(nil)
        state = JSON.parse(first.to_h.to_json)
        expect(deck_from(state).hand(nil)).to eq(ids)
      end
    end

    it "日付を省略すると、日本時間の今日を使うこと" do
      travel_to Time.zone.local(2026, 11, 2, 0, 30) do
        expect(described_class.new(nil, scope).to_h["date"]).to eq("2026-11-02")
      end
    end
  end

  describe "#draw" do
    let(:deck) { deck_from(nil) }
    let!(:first) do
      create_list(:place, 5, group: group)
      deck.hand(nil)
    end

    it "まだ出していない場所だけを引くこと" do
      expect(deck.draw(nil)).to match_array(scope.ids - first)
    end

    it "引き切ると空を返すこと" do
      deck.draw(nil)
      expect(deck.draw(nil)).to eq([])
    end
  end
end
