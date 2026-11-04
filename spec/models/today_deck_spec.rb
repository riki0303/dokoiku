require "rails_helper"

RSpec.describe TodayDeck do
  let(:group) { create(:group) }
  let(:scope) { Place.where(group: group) }
  let(:today) { Date.new(2026, 11, 2) }

  # セッションと同じく、前回の状態（Hash）を渡して作り直す
  def deck_from(state, on: today)
    described_class.new(state, scope, today: on)
  end

  # コントローラーの show と同じ流れ：手札があればそれを、なければ新しく引く
  def show(deck, distance)
    ids = deck.current_hand(distance)
    ids.empty? ? deck.draw(distance) : ids
  end

  describe "#current_hand" do
    before { create_list(:place, 5, group: group) }

    it "初回は山札を進めず空を返すこと", :aggregate_failures do
      deck = deck_from(nil)
      expect(deck.current_hand(nil)).to eq([])
      expect(deck.to_h["seen_ids"]).to eq([])
    end

    it "引いたときと同じ距離感なら同じ手札を返し、山札を進めないこと", :aggregate_failures do
      first = deck_from(nil)
      ids = first.draw(nil)
      second = deck_from(first.to_h)
      expect(second.current_hand(nil)).to eq(ids)
      expect(second.to_h["seen_ids"]).to eq([])
    end

    it "距離感が違うと空を返すこと" do
      first = deck_from(nil)
      first.draw(nil)
      expect(deck_from(first.to_h).current_hand("near")).to eq([])
    end

    it "手札の場所がすべて削除されると空を返すこと" do
      first = deck_from(nil)
      Place.where(id: first.draw(nil)).destroy_all
      expect(deck_from(first.to_h).current_hand(nil)).to eq([])
    end

    it "手札の一部が削除された場合、残りの手札だけを返すこと" do
      first = deck_from(nil)
      ids = first.draw(nil)
      Place.destroy(ids.first)
      expect(deck_from(first.to_h).current_hand(nil)).to eq(ids.drop(1))
    end

    it "セッションのキーが文字列の場合（Cookie を経由した場合）も同じ手札を返すこと" do
      first = deck_from(nil)
      ids = first.draw(nil)
      state = JSON.parse(first.to_h.to_json)
      expect(deck_from(state).current_hand(nil)).to eq(ids)
    end

    it "手札を出したあとに距離感が編集された場所は、その距離感の手札から外すこと" do
      first = deck_from(nil)
      ids = first.draw("near")
      Place.find(ids.first).update!(distance: :far)
      expect(deck_from(first.to_h).current_hand("near")).to eq(ids.drop(1))
    end
  end

  describe "#draw と #current_hand を組み合わせた流れ" do
    context "場所が3件より多い場合" do
      before { create_list(:place, 5, group: group) }

      it "自分のグループの場所から3件を引くこと", :aggregate_failures do
        create(:place, group: create(:group))
        ids = show(deck_from(nil), nil)
        expect(ids.size).to eq(3)
        expect(ids).to all(be_in(scope.ids))
      end

      it "同じ距離感でもう一度呼ぶと、同じ手札を返し山札を増やさないこと", :aggregate_failures do
        first = deck_from(nil)
        ids = show(first, nil)
        second = deck_from(first.to_h)
        expect(show(second, nil)).to eq(ids)
        expect(second.to_h["seen_ids"]).to eq([])
      end

      it "距離感が違うと、その距離感の手札を新しく引き、山札は進めないこと", :aggregate_failures do
        first = deck_from(nil)
        show(first, nil)
        deck = deck_from(first.to_h)
        expect(show(deck, "near").size).to eq(3)
        expect(deck.to_h["seen_ids"]).to eq([])
      end

      it "距離感ごとに手札を覚え、元の距離感に戻ると同じ手札を返すこと" do
        deck = deck_from(nil)
        first = [ nil, "near" ].map { |distance| show(deck, distance) }
        again = deck_from(JSON.parse(deck.to_h.to_json))
        expect([ nil, "near" ].map { |distance| show(again, distance) }).to eq(first)
      end

      it "手札の場所がすべて削除された場合、まだ出していない場所から引き直すこと" do
        deck = deck_from(nil)
        first = show(deck, nil)
        Place.where(id: first).destroy_all
        expect(show(deck_from(deck.to_h), nil)).to match_array(scope.ids)
      end
    end

    context "他の距離感で見送った場所が手札にある場合" do
      let!(:near_places) { create_list(:place, 2, group: group, distance: :near) }
      let!(:far_places) { create_list(:place, 2, group: group, distance: :far) }

      # 手札の中身を決めて試すため、セッションの Hash を直接組み立てる
      def deck_with_hands(hands)
        deck_from({ "date" => today.iso8601, "seen_ids" => [], "hands" => hands })
      end

      it "その場所を手札から外し、補充しないこと", :aggregate_failures do
        deck = deck_with_hands("all" => [ near_places.first.id, *far_places.map(&:id) ], "near" => [ near_places.first.id ])
        deck.redraw("near")
        expect(deck.to_h["seen_ids"]).to eq([ near_places.first.id ])
        expect(show(deck_from(deck.to_h), nil)).to eq(far_places.map(&:id))
      end

      it "手札がすべて外れたら、まだ見送っていない場所から新しく引くこと" do
        deck = deck_with_hands("all" => [ near_places.first.id ], "near" => [ near_places.first.id ])
        deck.redraw("near")
        expect(show(deck_from(deck.to_h), nil)).to contain_exactly(near_places.last.id, *far_places.map(&:id))
      end
    end

    context "引き切ったあとに場所が増えた場合" do
      before { create_list(:place, 2, group: group) }

      it "同じ距離感でも、増えた場所を引くこと" do
        deck = deck_from(nil)
        show(deck, nil)
        deck.redraw(nil)
        added = create(:place, group: group)
        expect(show(deck_from(deck.to_h), nil)).to eq([ added.id ])
      end
    end

    context "場所が3件未満の場合" do
      before { create_list(:place, 2, group: group) }

      it "ある分だけ引くこと" do
        expect(show(deck_from(nil), nil)).to match_array(scope.ids)
      end
    end

    context "距離感を指定した場合" do
      before do
        create_list(:place, 2, group: group, distance: :near)
        create_list(:place, 2, group: group, distance: :far)
      end

      it "その距離感の場所だけを引くこと" do
        expect(show(deck_from(nil), "far")).to match_array(scope.far.ids)
      end

      it "距離感を切り替えただけでは、別の距離感で出した場所も候補に残ること" do
        deck = deck_from(nil)
        show(deck, "near")
        expect(show(deck_from(deck.to_h), nil).size).to eq(3)
      end

      it "山札は距離感をまたいで共通で、別の距離感で見送った場所は出さないこと" do
        deck = deck_from(nil)
        show(deck, "near")
        deck.redraw("near")
        expect(show(deck_from(deck.to_h), nil)).to match_array(scope.far.ids)
      end
    end

    context "日付が変わった場合" do
      before { create_list(:place, 3, group: group) }

      it "山札をリセットし、同じ場所をまた引けること", :aggregate_failures do
        # 前日にすべて見送った状態
        deck = deck_from({ "date" => (today - 1).iso8601, "seen_ids" => scope.ids, "hands" => {} })
        expect(show(deck, nil)).to match_array(scope.ids)
        expect(deck.to_h["date"]).to eq(today.iso8601)
      end
    end

    it "日付を省略すると、日本時間の今日を使うこと" do
      travel_to Time.zone.local(2026, 11, 2, 0, 30) do
        expect(described_class.new(nil, scope).to_h["date"]).to eq("2026-11-02")
      end
    end
  end

  describe "#draw" do
    before { create_list(:place, 5, group: group) }

    it "引いた手札を山札に入れないこと", :aggregate_failures do
      deck = deck_from(nil)
      ids = deck.draw(nil)
      expect(deck.to_h["seen_ids"]).to eq([])
      expect(deck.current_hand(nil)).to eq(ids)
    end
  end

  describe "#redraw" do
    let(:deck) { deck_from(nil) }
    let!(:first) do
      create_list(:place, 5, group: group)
      deck.draw(nil)
    end

    it "いまの手札を山札に入れ、まだ見送っていない場所から引くこと", :aggregate_failures do
      expect(deck.redraw(nil)).to match_array(scope.ids - first)
      expect(deck.to_h["seen_ids"]).to match_array(first)
    end

    it "引き直した手札を、その距離感の手札として覚えること" do
      ids = deck.redraw(nil)
      expect(deck_from(deck.to_h).current_hand(nil)).to eq(ids)
    end

    it "引き切ると空を返すこと" do
      deck.redraw(nil)
      expect(deck.redraw(nil)).to eq([])
    end

    it "他の距離感の手札は山札に入れないこと" do
      deck.draw("near")
      deck.redraw(nil)
      expect(deck.to_h["seen_ids"]).to match_array(first)
    end
  end
end
