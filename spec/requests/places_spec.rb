require "rails_helper"

RSpec.describe "Places", type: :request do
  let(:user) { create(:user) }
  let(:valid_params) { { place: { name: "江ノ島", note: "夕日を見に行きたい", distance: "day_trip" } } }

  describe "GET /places" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get places_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで場所がある場合" do
      # 一覧に表示された場所の名前を上から順に返す
      let(:listed_names) { response.parsed_body.css(".list-group-item .fw-bold").map(&:text) }

      before do
        create(:place, group: user.group, name: "近所の公園", note: "散歩したい", distance: :near, created_at: 3.days.ago)
        create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip, created_at: 2.days.ago)
        create(:place, group: user.group, name: "駅前のカフェ", note: "パンが気になる", distance: :near, created_at: 1.day.ago)
        create(:place, group: create(:user).group, name: "他人の場所", distance: :near)
        sign_in user
      end

      it "自分のグループの場所だけを新しい順に表示すること", :aggregate_failures do
        get places_path
        expect(response).to have_http_status(:ok)
        expect(listed_names).to eq(%w[駅前のカフェ 江ノ島 近所の公園])
        expect(response.body).not_to include("他人の場所")
      end

      it "場所の名前・一言・距離感を表示すること" do
        get places_path
        expect(response.body).to include("江ノ島", "夕日を見に行きたい", "日帰り")
      end

      it "q[distance_eq]=near で近場の場所だけを表示すること" do
        get places_path, params: { q: { distance_eq: "near" } }
        expect(listed_names).to eq(%w[駅前のカフェ 近所の公園])
      end

      it "q がなければ全件を表示すること" do
        get places_path
        expect(listed_names.size).to eq(3)
      end

      it "q を何にしても他のグループの場所を表示しないこと", :aggregate_failures do
        [ {}, { distance_eq: "near" }, { group_id_eq: Place.find_by(name: "他人の場所").group_id }, { name_cont: "他人" } ].each do |q|
          get places_path, params: { q: q }
          expect(response.body).not_to include("他人の場所")
        end
      end

      it "許可していない条件を送っても無視すること" do
        get places_path, params: { q: { name_cont: "江ノ島" } }
        expect(listed_names).to eq(%w[駅前のカフェ 江ノ島 近所の公園])
      end

      it "並び替えを送っても無視し、新しい順のままにすること" do
        get places_path, params: { q: { s: "created_at asc" } }
        expect(listed_names).to eq(%w[駅前のカフェ 江ノ島 近所の公園])
      end

      it "すべて・近場・日帰り・遠出の絞り込みボタンを表示すること" do
        get places_path
        buttons = response.parsed_body.css("a.btn[href='#{places_path}'], a.btn[href^='#{places_path}?']")
        expect(buttons.map(&:text)).to eq(%w[すべて 近場 日帰り 遠出])
      end

      it "各絞り込みボタンのリンク先に距離感の条件を付けること" do
        get places_path
        links = response.parsed_body.css("nav a.btn").to_h { |link| [ link.text, link["href"] ] }
        expected = { "すべて" => places_path }
        expected.merge!(%w[近場 日帰り 遠出].zip(%w[near day_trip far]).to_h { |label, key| [ label, places_path(q: { distance_eq: key }) ] })
        expect(links).to eq(expected)
      end

      it "見出し横に登録画面へのリンクを表示すること" do
        get places_path
        expect(response.parsed_body.at_css("a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
      end

      it "選択中のボタンだけを塗りつぶし、aria-current を付けること", :aggregate_failures do
        get places_path, params: { q: { distance_eq: "near" } }
        current = response.parsed_body.css("a[aria-current='page']")
        expect(current.map(&:text)).to eq([ "近場" ])
        expect(response.parsed_body.css("a.btn-primary[href^='#{places_path}?']").map(&:text)).to eq([ "近場" ])
      end

      it "q がなければ「すべて」ボタンに aria-current を付けること" do
        get places_path
        expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "すべて" ])
      end

      it "時間や距離の数値表記を表示しないこと" do
        get places_path
        expect(response.body).not_to match(/\d+\s*(分|時間|km|キロ)/)
      end
    end

    context "ログイン済みで絞り込んだ結果だけ0件の場合" do
      before do
        create(:place, group: user.group, distance: :near)
        sign_in user
      end

      it "距離感入りの0件メッセージを表示し、絞り込みボタンは表示したままにすること", :aggregate_failures do
        get places_path, params: { q: { distance_eq: "far" } }
        expect(response.body).to include("遠出の場所はありません")
        expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "遠出" ])
        expect(response.body).not_to include("まだ場所がありません")
      end

      it "不正な値ならエラーにせず0件メッセージを表示すること", :aggregate_failures do
        get places_path, params: { q: { distance_eq: "xxx" } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("該当する場所はありません")
      end
    end

    context "ログイン済みで q が想定外の形の場合" do
      before do
        create(:place, group: user.group, name: "江ノ島")
        sign_in user
      end

      [ "q=near", "q[distance_eq][]=near" ].each do |query|
        it "#{query} ならエラーにせず全件を表示すること", :aggregate_failures do
          get "#{places_path}?#{query}"
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("江ノ島")
        end
      end
    end

    context "ログイン済みで場所が1件もない場合" do
      before do
        create(:place, group: create(:user).group)
        sign_in user
      end

      it "案内文と登録画面へのリンクを表示すること", :aggregate_failures do
        get places_path
        expect(response.body).to include("まだ場所がありません")
        expect(response.parsed_body.at_css("a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
      end

      it "絞り込みボタンを表示しないこと" do
        get places_path
        expect(response.parsed_body.css("a[href^='#{places_path}?']")).to be_empty
      end
    end
  end

  describe "GET /places/new" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get new_place_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in user }

      it "登録フォームを表示すること", :aggregate_failures do
        get new_place_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("場所の名前", "一言", "距離感")
      end

      it "距離感の選択肢として近場・日帰り・遠出を表示すること" do
        get new_place_path
        expect(response.body).to include("近場", "日帰り", "遠出")
      end

      it "時間や距離の数値表記を表示しないこと" do
        get new_place_path
        expect(response.body).not_to match(/\d+\s*(分|時間|km|キロ)/)
      end

      # request spec ではブラウザの入力チェックは動かないため、HTML5 の属性が出力されていることを確認する
      it "ブラウザの入力チェックを無効にする novalidate を付けないこと" do
        get new_place_path
        expect(response.parsed_body.at_css("form#new_place")["novalidate"]).to be_nil
      end

      it "場所の名前・一言に required と文字数上限を付けること", :aggregate_failures do
        get new_place_path
        form = response.parsed_body
        expect(form.at_css("input[name='place[name]']").to_h).to include("required" => "required", "maxlength" => "100")
        expect(form.at_css("input[name='place[note]']").to_h).to include("required" => "required", "maxlength" => "200")
      end

      it "距離感のラジオに required を付けること" do
        get new_place_path
        radios = response.parsed_body.css("input[type=radio][name='place[distance]']")
        expect(radios.map { |radio| radio["required"] }).to eq(%w[required required required])
      end

      it "距離感のラジオをどれも選択済みにしないこと" do
        get new_place_path
        expect(response.parsed_body.css("input[type=radio][name='place[distance]'][checked]")).to be_empty
      end

      it "一覧へのリンクを表示すること" do
        get new_place_path
        expect(response.parsed_body.at_css("a[href='#{places_path}']")&.text).to eq("一覧を見る")
      end
    end
  end

  describe "POST /places" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトし、場所を登録しないこと", :aggregate_failures do
        expect { post places_path, params: valid_params }.not_to change(Place, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで正しい入力の場合" do
      before { sign_in user }

      it "自分のグループに場所を登録すること", :aggregate_failures do
        expect { post places_path, params: valid_params }.to change(Place, :count).by(1)
        place = Place.last
        expect(place.group).to eq(user.group)
        expect(place).to have_attributes(name: "江ノ島", note: "夕日を見に行きたい", distance: "day_trip")
      end

      it "登録フォームにリダイレクトし、完了メッセージを表示すること", :aggregate_failures do
        post places_path, params: valid_params
        expect(response).to redirect_to(new_place_path)
        follow_redirect!
        expect(response.body).to include("江ノ島を登録しました")
      end
    end

    context "ログイン済みで他のグループの group_id を送った場合" do
      let(:other_group) { create(:user).group }

      before { sign_in user }

      it "送った group_id を無視して自分のグループに登録すること" do
        post places_path, params: { place: valid_params[:place].merge(group_id: other_group.id) }
        expect(Place.last.group).to eq(user.group)
      end
    end

    %i[name note distance].each do |attribute|
      context "ログイン済みで #{attribute} が空の場合" do
        let(:params) { { place: valid_params[:place].merge(attribute => "") } }
        # 空にした項目以外の入力値（距離感は選択状態のラジオ）がフォームに残っていること
        let(:kept_values) do
          { name: "江ノ島", note: "夕日を見に行きたい", distance: 'value="day_trip" checked="checked"' }.except(attribute).values
        end

        before { sign_in user }

        it "422 を返し、場所を登録しないこと", :aggregate_failures do
          expect { post places_path, params: params }.not_to change(Place, :count)
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "入力値を保持してフォームを再表示すること", :aggregate_failures do
          post places_path, params: params
          expect(response.body).to include("を入力してください")
          expect(response.body).to include(*kept_values)
        end
      end
    end
  end
end
