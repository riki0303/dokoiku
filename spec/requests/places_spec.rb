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

      it "見出しとタイトルに「場所一覧」を表示すること", :aggregate_failures do
        get places_path
        expect(response.parsed_body.at_css("h1")&.text).to eq("場所一覧")
        expect(response.parsed_body.at_css("title")&.text).to include("場所一覧")
      end

      it "見出し横に登録画面へのリンクを表示すること" do
        get places_path
        expect(response.parsed_body.at_css("main a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
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

      it "各行に訪問の記録画面と編集画面へのリンクを表示すること" do
        get places_path
        links = response.parsed_body.css(".list-group-item a").map { |link| [ link.text, link["href"] ] }
        places = Place.where(group: user.group).order(created_at: :desc)
        expected = places.flat_map { |place| [ [ "行った", new_place_visit_path(place) ], [ "編集", edit_place_path(place) ] ] }
        expect(links).to eq(expected)
      end

      it "「行った」リンクを「編集」リンクと同じ見た目にすること" do
        get places_path
        classes = response.parsed_body.css(".list-group-item a").map { |link| link["class"] }.uniq
        expect(classes).to eq([ "btn btn-link btn-sm py-0" ])
      end

      it "訪問済み一覧へのリンクを表示すること" do
        get places_path
        expect(response.parsed_body.at_css("main a[href='#{visits_path}']")).to be_present
      end
    end

    context "ログイン済みで訪問を記録した場所がある場合" do
      let(:listed_names) { response.parsed_body.css(".list-group-item .fw-bold").map(&:text) }

      before do
        create(:visit, place: create(:place, group: user.group, name: "もう行かない場所", distance: :near), want_again: false)
        create(:visit, place: create(:place, group: user.group, name: "また行きたい場所", distance: :near), want_again: true)
        create(:place, group: user.group, name: "まだ行っていない場所", distance: :near)
        sign_in user
      end

      it "消化済み（いいえ）の場所を表示せず、「はい」の場所は表示すること" do
        get places_path
        expect(listed_names).to contain_exactly("また行きたい場所", "まだ行っていない場所")
      end

      it "距離感で絞り込んでも消化済みの場所を表示しないこと" do
        get places_path, params: { q: { distance_eq: "near" } }
        expect(listed_names).to contain_exactly("また行きたい場所", "まだ行っていない場所")
      end
    end

    context "ログイン済みで行きたい場所をすべて消化した場合" do
      before do
        create(:visit, place: create(:place, group: user.group, name: "江ノ島"), want_again: false)
        sign_in user
        get places_path
      end

      it "場所がない場合と同じ「場所がありません」と登録画面へのリンクを表示すること", :aggregate_failures do
        expect(response.body).to include("場所がありません")
        expect(response.body).not_to include("江ノ島")
        expect(response.parsed_body.css("main a[href='#{new_place_path}']").map(&:text)).to eq([ "場所を登録する" ])
      end

      it "絞り込みボタンと見出し横の登録ボタンを表示しないこと", :aggregate_failures do
        expect(response.parsed_body.css("a[href^='#{places_path}?']")).to be_empty
        expect(response.parsed_body.css("main a.btn-sm[href='#{new_place_path}']")).to be_empty
      end

      it "訪問済み一覧へのリンクを表示すること" do
        expect(response.parsed_body.at_css("main a[href='#{visits_path}']")).to be_present
      end
    end

    context "ログイン済みで絞り込んだ結果だけ0件の場合" do
      before do
        create(:place, group: user.group, distance: :near)
        sign_in user
      end

      it "「場所がありません」を表示し、絞り込みボタンは表示したままにすること", :aggregate_failures do
        get places_path, params: { q: { distance_eq: "far" } }
        expect(response.body).to include("場所がありません")
        expect(response.parsed_body.css("a[aria-current='page']").map(&:text)).to eq([ "遠出" ])
      end

      it "不正な値ならエラーにせず「場所がありません」を表示すること", :aggregate_failures do
        get places_path, params: { q: { distance_eq: "xxx" } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("場所がありません")
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

    context "ログイン済みで一言に URL がある場合" do
      before do
        create(:place, group: user.group, name: "駅前のカフェ", note: "メニューは https://example.com/menu を見る")
        sign_in user
      end

      it "一言の URL を新しいタブで開くリンクにすること" do
        get places_path
        link = response.parsed_body.at_css(".list-group-item a[href='https://example.com/menu']")
        expect(link.to_h).to include("target" => "_blank", "rel" => "noopener noreferrer")
      end
    end

    context "ログイン済みで場所が1件もない場合" do
      before do
        create(:place, group: create(:user).group)
        sign_in user
      end

      it "案内文と登録画面へのリンクを表示すること", :aggregate_failures do
        get places_path
        expect(response.body).to include("場所がありません")
        expect(response.parsed_body.at_css("main a[href='#{new_place_path}']")&.text).to eq("場所を登録する")
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
        expect(response.parsed_body.at_css("main a[href='#{places_path}']")&.text).to eq("一覧を見る")
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

    context "ログイン済みで distance に不正な値を送った場合" do
      let(:params) { { place: valid_params[:place].merge(distance: "xxx") } }

      before { sign_in user }

      it "422 を返し、場所を登録しないこと", :aggregate_failures do
        expect { post places_path, params: params }.not_to change(Place, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "エラーを表示し、名前・一言の入力値を保持してフォームを再表示すること", :aggregate_failures do
        post places_path, params: params
        expect(response.body).to include("距離感は一覧にありません")
        expect(response.parsed_body.at_css("input[name='place[name]']")["value"]).to eq("江ノ島")
        expect(response.parsed_body.at_css("input[name='place[note]']")["value"]).to eq("夕日を見に行きたい")
      end

      it "距離感のラジオをどれも選択済みにしないこと" do
        post places_path, params: params
        expect(response.parsed_body.css("input[type=radio][name='place[distance]'][checked]")).to be_empty
      end
    end
  end

  describe "GET /places/:id/edit" do
    let!(:place) { create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get edit_place_path(place)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで自分のグループの場所の場合" do
      let(:html) { response.parsed_body }
      let(:delete_form) { html.at_css("form[data-turbo-confirm]") }

      before do
        sign_in user
        get edit_place_path(place)
      end

      it "今の値が入った編集フォームを表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(html.at_css("input[name='place[name]']")["value"]).to eq("江ノ島")
        expect(html.at_css("input[name='place[note]']")["value"]).to eq("夕日を見に行きたい")
        expect(html.at_css("input[type=radio][name='place[distance]'][checked]")["value"]).to eq("day_trip")
      end

      it "確認ダイアログ付きの削除ボタンを表示すること", :aggregate_failures do
        expect(delete_form.to_h).to include("action" => place_path(place), "data-turbo-confirm" => "江ノ島を削除しますか？")
        expect(delete_form.at_css("input[name='_method']")["value"]).to eq("delete")
        expect(delete_form.at_css("button").text).to eq("削除する")
      end

      # フォームの中にフォームがあると HTML として壊れるため
      it "削除ボタンを編集フォームの外に置くこと" do
        expect(delete_form.ancestors("form")).to be_empty
      end

      it "一覧へ戻るリンクを表示すること" do
        expect(html.at_css("main a[href='#{places_path}']")&.text).to eq("一覧に戻る")
      end
    end

    context "ログイン済みで他のグループの場所の場合" do
      let(:other_place) { create(:place, group: create(:user).group) }

      before { sign_in user }

      it "404 を返し、flash を出さないこと", :aggregate_failures do
        get edit_place_path(other_place)
        expect(response).to have_http_status(:not_found)
        expect(flash[:alert]).to be_nil
      end
    end
  end

  describe "PATCH /places/:id" do
    let!(:place) { create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip) }
    let(:update_params) { { place: { name: "鎌倉", note: "大仏を見たい", distance: "far" } } }

    context "未ログインの場合" do
      it "ログインページにリダイレクトし、場所を更新しないこと", :aggregate_failures do
        patch place_path(place), params: update_params
        expect(response).to redirect_to(new_user_session_path)
        expect(place.reload.name).to eq("江ノ島")
      end
    end

    context "ログイン済みで正しい入力の場合" do
      before { sign_in user }

      it "場所を更新すること" do
        patch place_path(place), params: update_params
        expect(place.reload).to have_attributes(name: "鎌倉", note: "大仏を見たい", distance: "far")
      end

      it "一覧にリダイレクトし、完了メッセージを表示すること", :aggregate_failures do
        patch place_path(place), params: update_params
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("鎌倉を更新しました")
      end
    end

    context "ログイン済みで他のグループの group_id を送った場合" do
      let(:other_group) { create(:user).group }

      before { sign_in user }

      it "送った group_id を無視し、グループを変えないこと" do
        patch place_path(place), params: { place: update_params[:place].merge(group_id: other_group.id) }
        expect(place.reload.group).to eq(user.group)
      end
    end

    context "ログイン済みで名前が空の場合" do
      let(:params) { { place: update_params[:place].merge(name: "") } }

      before { sign_in user }

      it "422 を返し、場所を更新しないこと", :aggregate_failures do
        patch place_path(place), params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(place.reload).to have_attributes(name: "江ノ島", note: "夕日を見に行きたい", distance: "day_trip")
      end

      it "入力値を保持して編集フォームを再表示すること", :aggregate_failures do
        patch place_path(place), params: params
        expect(response.body).to include("を入力してください", "大仏を見たい", 'value="far" checked="checked"')
        expect(response.parsed_body.at_css("input[type=submit]")["value"]).to eq("更新する")
      end

      it "削除の確認文言には未保存の名前ではなく DB 上の名前を使うこと" do
        patch place_path(place), params: params
        expect(response.parsed_body.at_css("form[data-turbo-confirm]")["data-turbo-confirm"]).to eq("江ノ島を削除しますか？")
      end
    end

    context "ログイン済みで distance に不正な値を送った場合" do
      let(:params) { { place: update_params[:place].merge(distance: "xxx") } }

      before { sign_in user }

      it "422 を返し、場所を更新しないこと", :aggregate_failures do
        patch place_path(place), params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(place.reload).to have_attributes(name: "江ノ島", note: "夕日を見に行きたい", distance: "day_trip")
      end

      it "入力値を保持して編集フォームを再表示すること", :aggregate_failures do
        patch place_path(place), params: params
        expect(response.body).to include("距離感は一覧にありません")
        expect(response.parsed_body.at_css("input[name='place[name]']")["value"]).to eq("鎌倉")
        expect(response.parsed_body.at_css("input[name='place[note]']")["value"]).to eq("大仏を見たい")
        expect(response.parsed_body.at_css("input[type=submit]")["value"]).to eq("更新する")
      end

      it "距離感のラジオをどれも選択済みにしないこと" do
        patch place_path(place), params: params
        expect(response.parsed_body.css("input[type=radio][name='place[distance]'][checked]")).to be_empty
      end
    end

    context "ログイン済みで他のグループの場所の場合" do
      let!(:other_place) { create(:place, group: create(:user).group, name: "他人の場所") }

      before { sign_in user }

      it "404 を返し、場所を更新せず、flash を出さないこと", :aggregate_failures do
        patch place_path(other_place), params: update_params
        expect(response).to have_http_status(:not_found)
        expect(other_place.reload.name).to eq("他人の場所")
        expect(flash[:alert]).to be_nil
      end
    end
  end

  describe "DELETE /places/:id" do
    let!(:place) { create(:place, group: user.group, name: "江ノ島") }

    context "未ログインの場合" do
      it "ログインページにリダイレクトし、場所を削除しないこと", :aggregate_failures do
        expect { delete place_path(place) }.not_to change(Place, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで自分のグループの場所の場合" do
      before { sign_in user }

      it "場所を削除すること", :aggregate_failures do
        expect { delete place_path(place) }.to change(Place, :count).by(-1)
        expect(Place.exists?(place.id)).to be(false)
      end

      it "303 で一覧にリダイレクトし、完了メッセージを表示すること", :aggregate_failures do
        delete place_path(place)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("江ノ島を削除しました")
      end

      it "訪問記録がある場所を削除すると、訪問記録も消して 303 を返すこと", :aggregate_failures do
        create_list(:visit, 2, place: place, want_again: true)
        expect { delete place_path(place) }.to change(Visit, :count).by(-2)
        expect(response).to have_http_status(:see_other)
      end
    end

    context "ログイン済みで他のグループの場所の場合" do
      let!(:other_place) { create(:place, group: create(:user).group) }

      before { sign_in user }

      it "404 を返し、場所を削除せず、flash を出さないこと", :aggregate_failures do
        expect { delete place_path(other_place) }.not_to change(Place, :count)
        expect(response).to have_http_status(:not_found)
        expect(flash[:alert]).to be_nil
      end
    end
  end
end
