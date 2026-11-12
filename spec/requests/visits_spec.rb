require "rails_helper"

RSpec.describe "Visits", type: :request do
  let(:user) { create(:user) }
  let(:place) { create(:place, group: user.group, name: "江ノ島") }
  let(:valid_params) { { visit: { visited_on: Date.current.iso8601, want_again: "false" } } }

  # 行きたい場所の画面に出ている場所の名前
  def wanted_place_names
    get places_path
    response.parsed_body.css(".list-group-item .fw-bold").map(&:text)
  end

  describe "GET /places/:place_id/visits/new" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get new_place_visit_path(place)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで行きたい場所に残っている場所の場合" do
      let(:html) { response.parsed_body }

      before do
        sign_in user
        get new_place_visit_path(place)
      end

      it "対象の場所の名前を表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("江ノ島")
      end

      it "訪問日の初期値を今日にすること" do
        expect(html.at_css("input[name='visit[visited_on]']")["value"]).to eq(Date.current.iso8601)
      end

      it "また行きたいかのラジオをどれも選択済みにしないこと" do
        expect(html.css("input[type=radio][name='visit[want_again]'][checked]")).to be_empty
      end
    end

    context "ログイン済みで消化済みの場所の場合" do
      before do
        create(:visit, place: place, want_again: false)
        sign_in user
      end

      it "404 を返すこと" do
        get new_place_visit_path(place)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "ログイン済みで「はい」の記録がある場所の場合" do
      before do
        create(:visit, place: place, want_again: true)
        sign_in user
      end

      it "記録フォームを表示すること" do
        get new_place_visit_path(place)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /places/:place_id/visits" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトし、記録しないこと", :aggregate_failures do
        expect { post place_visits_path(place), params: valid_params }.not_to change(Visit, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで「いいえ」を選んだ場合" do
      before { sign_in user }

      it "訪問記録を作ること", :aggregate_failures do
        expect { post place_visits_path(place), params: valid_params }.to change(Visit, :count).by(1)
        expect(Visit.last).to have_attributes(place: place, visited_on: Date.current, want_again: false)
      end

      it "行きたい場所にリダイレクトし、訪問済みにしたことを表示すること", :aggregate_failures do
        post place_visits_path(place), params: valid_params
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("江ノ島を訪問済みにしました")
      end

      it "行きたい場所から消えること" do
        create(:place, group: user.group, name: "鎌倉")
        post place_visits_path(place), params: valid_params
        expect(wanted_place_names).to eq(%w[鎌倉])
      end
    end

    context "ログイン済みで「はい」を選んだ場合" do
      let(:params) { { visit: { visited_on: 3.days.ago.to_date.iso8601, want_again: "true" } } }

      before { sign_in user }

      it "訪問記録を作ること" do
        post place_visits_path(place), params: params
        expect(Visit.last).to have_attributes(place: place, visited_on: 3.days.ago.to_date, want_again: true)
      end

      it "行きたい場所にリダイレクトし、行きたい場所に残ることを表示すること", :aggregate_failures do
        post place_visits_path(place), params: params
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("江ノ島の訪問を記録しました（行きたい場所に残ります）")
      end

      it "行きたい場所に残ること" do
        post place_visits_path(place), params: params
        expect(wanted_place_names).to eq(%w[江ノ島])
      end

      it "同じ場所に2回目の記録ができること" do
        post place_visits_path(place), params: params
        expect { post place_visits_path(place), params: valid_params }.to change(place.visits, :count).by(1)
      end
    end

    context "ログイン済みで訪問日が明日の場合" do
      let(:params) { { visit: { visited_on: Date.current.tomorrow.iso8601, want_again: "false" } } }

      before { sign_in user }

      it "422 を返し、記録しないこと", :aggregate_failures do
        expect { post place_visits_path(place), params: params }.not_to change(Visit, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "エラーを表示し、入力値を保持してフォームを再表示すること", :aggregate_failures do
        post place_visits_path(place), params: params
        expect(response.body).to include("訪問日は今日以前の日付を入力してください")
        expect(response.parsed_body.at_css("input[name='visit[visited_on]']")["value"]).to eq(Date.current.tomorrow.iso8601)
        expect(response.parsed_body.at_css("input[type=radio][name='visit[want_again]'][checked]")["value"]).to eq("false")
      end
    end

    context "ログイン済みで訪問日が空の場合" do
      let(:params) { { visit: { visited_on: "", want_again: "true" } } }

      before { sign_in user }

      it "422 を返し、エラーと選んだ値を保持してフォームを再表示すること", :aggregate_failures do
        expect { post place_visits_path(place), params: params }.not_to change(Visit, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("訪問日を入力してください")
        expect(response.parsed_body.at_css("input[type=radio][name='visit[want_again]'][checked]")["value"]).to eq("true")
      end
    end

    context "ログイン済みでまた行きたいかが未選択の場合" do
      let(:params) { { visit: { visited_on: 2.days.ago.to_date.iso8601 } } }

      before { sign_in user }

      it "422 を返し、記録しないこと", :aggregate_failures do
        expect { post place_visits_path(place), params: params }.not_to change(Visit, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "エラーを表示し、訪問日を保持してフォームを再表示すること", :aggregate_failures do
        post place_visits_path(place), params: params
        expect(response.body).to include("また行きたいかを選択してください")
        expect(response.parsed_body.at_css("input[name='visit[visited_on]']")["value"]).to eq(2.days.ago.to_date.iso8601)
        expect(response.parsed_body.css("input[type=radio][name='visit[want_again]'][checked]")).to be_empty
      end
    end

    context "ログイン済みで消化済みの場所の場合" do
      before do
        create(:visit, place: place, want_again: false)
        sign_in user
      end

      it "404 を返し、記録しないこと", :aggregate_failures do
        expect { post place_visits_path(place), params: valid_params }.not_to change(Visit, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /visits" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトすること" do
        get visits_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで訪問記録がある場合" do
      let(:items) { response.parsed_body.css(".list-group-item") }

      before do
        enoshima = create(:place, group: user.group, name: "江ノ島", note: "夕日を見に行きたい", distance: :day_trip)
        cafe = create(:place, group: user.group, name: "駅前のカフェ", note: "パンが気になる", distance: :near)
        park = create(:place, group: user.group, name: "近所の公園", note: "散歩したい", distance: :near)
        create(:visit, place: enoshima, visited_on: Date.new(2026, 10, 1), want_again: true)
        create(:visit, place: cafe, visited_on: Date.new(2026, 10, 20), want_again: false)
        # 同じ訪問日なら、あとに記録したものを上にする
        create(:visit, place: park, visited_on: Date.new(2026, 10, 1), want_again: false, created_at: 1.minute.from_now)
        sign_in user
        get visits_path
      end

      it "記録を訪問日の新しい順に表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(items.map { |item| item.at_css(".fw-bold").text }).to eq(%w[駅前のカフェ 近所の公園 江ノ島])
      end

      it "場所の名前・一言・距離感・訪問日・また行きたいかを表示すること", :aggregate_failures do
        item = items.find { |li| li.at_css(".fw-bold").text == "江ノ島" }
        expect(item.text).to include("夕日を見に行きたい", "日帰り", "2026/10/01", "はい")
        cafe = items.find { |li| li.at_css(".fw-bold").text == "駅前のカフェ" }
        expect(cafe.at_css(".want-again").text).to include("いいえ")
      end
    end

    context "ログイン済みで訪問した場所の一言に URL がある場合" do
      before do
        create(:visit, place: create(:place, group: user.group, name: "駅前のカフェ", note: "メニューは https://example.com/menu を見る"))
        sign_in user
      end

      it "一言の URL をリンクにすること" do
        get visits_path
        expect(response.parsed_body.at_css("a[href='https://example.com/menu']")).to be_present
      end
    end

    context "ログイン済みで訪問記録が1件もない場合" do
      before { sign_in user }

      it "案内文を表示すること", :aggregate_failures do
        get visits_path
        expect(response.body).to include("まだ訪問した場所はありません")
        expect(response.parsed_body.css(".list-group-item")).to be_empty
      end
    end
  end

  describe "DELETE /visits/:id" do
    let!(:visit) { create(:visit, place: place, want_again: false) }

    context "未ログインの場合" do
      it "ログインページにリダイレクトし、記録を消さないこと", :aggregate_failures do
        expect { delete visit_path(visit) }.not_to change(Visit, :count)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "ログイン済みで自分のグループの記録の場合" do
      before { sign_in user }

      it "記録を消すこと" do
        expect { delete visit_path(visit) }.to change(Visit, :count).by(-1)
      end

      it "303 で訪問記録の一覧にリダイレクトし、完了メッセージを表示すること", :aggregate_failures do
        delete visit_path(visit)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(visits_path)
        follow_redirect!
        expect(response.body).to include("江ノ島の訪問記録を取り消しました")
      end

      it "「いいえ」の記録を取り消すと、行きたい場所に戻ること", :aggregate_failures do
        expect(wanted_place_names).to be_empty
        delete visit_path(visit)
        expect(wanted_place_names).to eq(%w[江ノ島])
      end
    end
  end
end
