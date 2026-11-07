require "rails_helper"

RSpec.describe "Decisions", type: :request do
  let(:user) { create(:user) }

  # 画面に出ている場所の名前（カードの見出し）。リクエストのたびに読み直すため let ではなくメソッドにする
  def shown_names
    response.parsed_body.css(".card-title").map(&:text)
  end

  # 距離感を選んで今日決める画面を開き、出ている場所の名前を返す。distance が nil なら「すべて」
  def shown_names_for(distance)
    get root_path, params: { distance: distance }.compact
    shown_names
  end

  describe "GET /" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで場所が3件より多い場合" do
      before do
        %w[公園 カフェ 図書館 美術館 温泉].each { |name| create(:place, group: user.group, name: name, distance: :near) }
        sign_in user
      end

      it "自分のグループの場所から3件を表示すること", :aggregate_failures do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(shown_names.size).to eq(3)
        expect(shown_names).to all(be_in(%w[公園 カフェ 図書館 美術館 温泉]))
      end

      it "再読み込みしても同じ3件を表示すること" do
        get root_path
        first = shown_names
        get root_path
        expect(shown_names).to eq(first)
      end

      it "「別の3件」は 303 でトップにリダイレクトすること", :aggregate_failures do
        post redraw_decision_path
        expect(response).to redirect_to(root_path)
        expect(response).to have_http_status(:see_other)
      end

      it "「別の3件」で、まだ出ていない場所を表示すること", :aggregate_failures do
        get root_path
        first = shown_names
        post redraw_decision_path
        follow_redirect!
        expect(shown_names).to match_array(%w[公園 カフェ 図書館 美術館 温泉] - first)
      end
    end

    context "ログイン済みで山札を引き切った場合" do
      before do
        create_list(:place, 3, group: user.group)
        sign_in user
        get root_path
        post redraw_decision_path
        get root_path
      end

      it "「まだ場所がありません」と登録画面へのリンクを表示すること", :aggregate_failures do
        expect(shown_names).to be_empty
        expect(response.body).to include("まだ場所がありません")
        expect(response.parsed_body.at_css("main a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
      end

      it "新しく登録した場所を、再読み込みで表示すること" do
        create(:place, group: user.group, name: "新しい場所")
        get root_path
        expect(shown_names).to eq(%w[新しい場所])
      end

      it "絞り込みボタンは表示したままにし、「別の3件」ボタンは表示しないこと", :aggregate_failures do
        expect(response.parsed_body.css("main nav a.btn").map(&:text)).to eq(%w[すべて 近場 日帰り 遠出])
        expect(response.body).not_to include("別の3件")
      end
    end

    context "ログイン済みで場所がある場合" do
      before do
        create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip, created_at: 3.months.ago)
        create(:place, group: create(:user).group, name: "他人の場所")
        sign_in user
      end

      it "場所の名前・一言・距離感・経過期間を表示すること" do
        get root_path
        expect(response.body).to include("江ノ島", "夕日を見に行きたい", "日帰り", "3ヶ月前に登録")
      end

      it "名前を一言より前に、大きく表示すること", :aggregate_failures do
        get root_path
        card = response.parsed_body.at_css(".card-body")
        expect(card.css(".card-title, .card-text").map(&:text)).to eq(%w[江ノ島 夕日を見に行きたい])
        expect(card.at_css(".card-title")["class"]).to include("fs-4", "fw-bold")
      end

      it "他のグループの場所を表示しないこと" do
        get root_path
        expect(response.body).not_to include("他人の場所")
      end

      it "時間や距離の数値表記を表示しないこと" do
        get root_path
        expect(response.body).not_to match(/\d+\s*(分|時間|km|キロ)/)
      end

      it "「これにする」で、場所の名前を検索する Google マップを新しいタブで開くこと" do
        get root_path
        link = response.parsed_body.css("a").find { |a| a.text == "これにする" }
        url = "https://www.google.com/maps/search/?api=1&query=%E6%B1%9F%E3%83%8E%E5%B3%B6"
        expect(link.to_h).to include("href" => url, "target" => "_blank", "rel" => "noopener noreferrer")
      end

      it "「別の3件」ボタンを表示すること" do
        get root_path
        expect(response.parsed_body.at_css("form[action='#{redraw_decision_path}'][method='post'] button")&.text).to eq("別の3件")
      end

      it "Turbo のホバー先読みを止める meta を出さないこと" do
        get root_path
        expect(response.parsed_body.at_css("meta[name='turbo-prefetch']")).to be_nil
      end

      it "ナビバーに場所の登録・ストック一覧へのリンクを表示すること" do
        get root_path
        links = response.parsed_body.css("nav.navbar a").to_h { |link| [ link.text, link["href"] ] }
        expect(links).to include("場所を登録" => new_place_path, "ストック一覧" => places_path)
      end
    end

    context "ログイン済みで距離感で絞り込む場合" do
      before do
        create(:place, group: user.group, name: "公園", distance: :near)
        create(:place, group: user.group, name: "江ノ島", distance: :day_trip)
        create(:place, group: user.group, name: "京都", distance: :far)
        sign_in user
      end

      it "すべて・近場・日帰り・遠出の絞り込みボタンを表示すること" do
        get root_path
        links = response.parsed_body.css("main nav a.btn").to_h { |link| [ link.text, link["href"] ] }
        expected = { "すべて" => root_path }
        expected.merge!(%w[近場 日帰り 遠出].zip(%w[near day_trip far]).to_h { |label, key| [ label, root_path(distance: key) ] })
        expect(links).to eq(expected)
      end

      it "distance=far で遠出の場所だけを表示し、遠出ボタンを選択中にすること", :aggregate_failures do
        get root_path, params: { distance: "far" }
        expect(shown_names).to eq(%w[京都])
        expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "遠出" ])
      end

      it "distance がなければ「すべて」を選択中にすること" do
        get root_path
        expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "すべて" ])
      end

      [ "distance=xxx", "distance[]=near", "distance[a]=near" ].each do |query|
        it "#{query} ならエラーにせず「すべて」として扱うこと", :aggregate_failures do
          get "#{root_path}?#{query}"
          expect(response).to have_http_status(:ok)
          expect(shown_names).to match_array(%w[公園 江ノ島 京都])
          expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "すべて" ])
        end
      end

      it "距離感を何度切り替えても、山札を減らさず各距離感で1周目と同じ手札を表示すること", :aggregate_failures do
        laps = Array.new(3) { [ nil, "near", "day_trip", "far" ].map { |distance| shown_names_for(distance) } }
        expect(laps.first).to all(be_present)
        expect(laps).to all(eq(laps.first))
      end

      it "「すべて → 近場 → すべて」と切り替えると、同じ手札に戻ること" do
        first = shown_names_for(nil)
        shown_names_for("near")
        expect(shown_names_for(nil)).to eq(first)
      end

      it "近場で「別の3件」を押したあと「すべて」に戻ると、見送った場所だけが外れた手札を表示すること" do
        first = shown_names_for(nil)
        shown_names_for("near")
        post redraw_decision_path, params: { distance: "near" }
        expect(shown_names_for(nil)).to eq(first - %w[公園])
      end

      it "まだ手札のない距離感で「別の3件」を押しても、何も見送らず他の距離感の手札を変えないこと", :aggregate_failures do
        first = shown_names_for(nil)
        post redraw_decision_path, params: { distance: "far" }
        expect(shown_names_for("far")).to eq(%w[京都])
        expect(shown_names_for(nil)).to eq(first)
      end

      it "選んだ距離感に場所がなければ「まだ場所がありません」を表示すること" do
        get root_path, params: { distance: "far" }
        post redraw_decision_path, params: { distance: "far" }
        follow_redirect!
        expect(response.body).to include("まだ場所がありません")
      end

      it "「別の3件」は選んでいる距離感を保ったままリダイレクトすること" do
        post redraw_decision_path, params: { distance: "near" }
        expect(response).to redirect_to(root_path(distance: "near"))
      end

      it "「別の3件」ボタンに選んでいる距離感を持たせること" do
        get root_path, params: { distance: "near" }
        expect(response.parsed_body.at_css("form[action='#{redraw_decision_path}'] input[name='distance']")&.[]("value")).to eq("near")
      end
    end

    context "ログイン済みで日付が変わった場合" do
      before do
        create(:place, group: user.group, name: "江ノ島")
        sign_in user
        # 前日の 23:50（日本時間）に引き切っておく
        travel_to Time.zone.local(2026, 11, 1, 23, 50) do
          get root_path
          post redraw_decision_path
        end
      end

      it "同じ日のうちは候補を出さないこと" do
        travel_to(Time.zone.local(2026, 11, 1, 23, 55)) { get root_path }
        expect(response.body).to include("まだ場所がありません")
      end

      it "日本時間で日付が変わると山札をリセットし、前日に出した場所をまた表示すること" do
        travel_to(Time.zone.local(2026, 11, 2, 0, 10)) { get root_path }
        expect(shown_names).to eq(%w[江ノ島])
      end
    end

    context "ログイン済みで手札を出したあとに場所が削除された場合" do
      before do
        create(:place, group: user.group, name: "江ノ島")
        sign_in user
      end

      it "削除された場所を表示しないこと" do
        get root_path
        Place.find_by!(name: "江ノ島").destroy!
        get root_path
        expect(response.body).not_to include("江ノ島")
      end

      it "手札がすべて削除されたら、まだ出ていない場所から引き直すこと" do
        get root_path
        Place.find_by!(name: "江ノ島").destroy!
        create(:place, group: user.group, name: "高尾山")
        get root_path
        expect(shown_names).to eq(%w[高尾山])
      end
    end

    context "ログイン済みで訪問を記録した場所がある場合" do
      before do
        create(:visit, place: create(:place, group: user.group, name: "もう行かない場所"), want_again: false)
        create(:visit, place: create(:place, group: user.group, name: "また行きたい場所"), want_again: true)
        create(:place, group: user.group, name: "まだ行っていない場所")
        sign_in user
      end

      it "消化済み（いいえ）の場所を候補に出さず、「はい」の場所は出すこと" do
        get root_path
        expect(shown_names).to contain_exactly("また行きたい場所", "まだ行っていない場所")
      end

      it "手札を出したあとに消化した場所を表示しないこと" do
        get root_path
        create(:visit, place: Place.find_by!(name: "また行きたい場所"), want_again: false)
        get root_path
        expect(shown_names).to eq(%w[まだ行っていない場所])
      end

      it "「別の3件」では消化済みの場所を引かないこと", :aggregate_failures do
        get root_path
        post redraw_decision_path
        follow_redirect!
        expect(shown_names).to be_empty
        expect(response.body).to include("まだ場所がありません")
      end
    end

    context "ログイン済みでストックをすべて消化した場合" do
      before do
        create(:visit, place: create(:place, group: user.group, name: "江ノ島"), want_again: false)
        sign_in user
        get root_path
      end

      it "場所がない場合と同じ「まだ場所がありません」と登録画面へのリンクを表示すること", :aggregate_failures do
        expect(shown_names).to be_empty
        expect(response.body).to include("まだ場所がありません")
        expect(response.parsed_body.at_css("main a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
      end
    end

    context "ログイン済みで場所が1件もない場合" do
      before do
        create(:place, group: create(:user).group)
        sign_in user
      end

      it "「まだ場所がありません」と登録画面へのリンクを表示すること", :aggregate_failures do
        get root_path
        expect(response.body).to include("まだ場所がありません")
        expect(response.parsed_body.at_css("main a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
      end

      it "絞り込みボタンと「別の3件」ボタンを表示しないこと", :aggregate_failures do
        get root_path
        expect(response.parsed_body.css("main nav")).to be_empty
        expect(response.body).not_to include("別の3件")
      end
    end
  end

  describe "POST /decision/redraw" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        post redraw_decision_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
