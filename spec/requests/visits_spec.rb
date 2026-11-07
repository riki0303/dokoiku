require "rails_helper"

RSpec.describe "Visits", type: :request do
  let(:user) { create(:user) }
  let(:place) { create(:place, group: user.group, name: "江ノ島") }
  let(:valid_params) { { visit: { visited_on: Date.current.iso8601, want_again: "false" } } }

  # ストック一覧に出ている場所の名前
  def stock_names
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

    context "ログイン済みでストックに残っている場所の場合" do
      let(:html) { response.parsed_body }

      before do
        sign_in user
        get new_place_visit_path(place)
      end

      it "対象の場所の名前と記録フォームを表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(html.at_css("h1").text).to eq("訪問を記録する")
        expect(response.body).to include("江ノ島", "訪問日", "また行きたいか")
        expect(html.at_css("main form")["action"]).to eq(place_visits_path(place))
      end

      it "訪問日の初期値を今日にし、明日以降を選べないよう上限を付けること" do
        input = html.at_css("input[name='visit[visited_on]']")
        expect(input.to_h).to include("type" => "date", "value" => Date.current.iso8601, "max" => Date.current.iso8601)
      end

      it "また行きたいかを「はい / いいえ」のラジオで出し、どれも選択済みにしないこと", :aggregate_failures do
        radios = html.css("input[type=radio][name='visit[want_again]']")
        expect(radios.map { |radio| radio["value"] }).to eq(%w[true false])
        expect(radios.map { |radio| html.at_css("label[for='#{radio['id']}']").text }).to eq(%w[はい いいえ])
        expect(radios.select { |radio| radio["checked"] }).to be_empty
      end

      it "訪問日の入力とまた行きたいかのラジオに required を付けること", :aggregate_failures do
        expect(html.at_css("input[name='visit[visited_on]']")["required"]).to eq("required")
        radios = html.css("input[type=radio][name='visit[want_again]']")
        expect(radios.map { |radio| radio["required"] }).to eq(%w[required required])
      end

      it "訪問日とまた行きたいかのラベルに必須バッジを表示すること" do
        labels = html.css("main form label, main form legend").select { |label| label.at_css(".badge.text-bg-danger") }
        expect(labels.map { |label| label.text.sub("必須", "").strip }).to eq(%w[訪問日 また行きたいか])
      end

      it "送信ボタンと一覧に戻るリンクを表示すること", :aggregate_failures do
        expect(html.at_css("input[type=submit]")["value"]).to eq("記録する")
        expect(html.at_css("main a[href='#{places_path}']")&.text).to eq("一覧に戻る")
      end
    end

    context "ログイン済みで他のグループの場所の場合" do
      let(:other_place) { create(:place, group: create(:user).group) }

      before { sign_in user }

      it "404 を返し、public/404.html を表示して flash を出さないこと", :aggregate_failures do
        get new_place_visit_path(other_place)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq(Rails.public_path.join("404.html").read)
        expect(flash[:alert]).to be_nil
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

      it "ストック一覧にリダイレクトし、訪問済みにしたことを表示すること", :aggregate_failures do
        post place_visits_path(place), params: valid_params
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("江ノ島を訪問済みにしました")
      end

      it "ストック一覧から消えること" do
        create(:place, group: user.group, name: "鎌倉")
        post place_visits_path(place), params: valid_params
        expect(stock_names).to eq(%w[鎌倉])
      end
    end

    context "ログイン済みで「はい」を選んだ場合" do
      let(:params) { { visit: { visited_on: 3.days.ago.to_date.iso8601, want_again: "true" } } }

      before { sign_in user }

      it "訪問記録を作ること" do
        post place_visits_path(place), params: params
        expect(Visit.last).to have_attributes(place: place, visited_on: 3.days.ago.to_date, want_again: true)
      end

      it "ストック一覧にリダイレクトし、ストックに残ることを表示すること", :aggregate_failures do
        post place_visits_path(place), params: params
        expect(response).to redirect_to(places_path)
        follow_redirect!
        expect(response.body).to include("江ノ島の訪問を記録しました（ストックに残ります）")
      end

      it "ストック一覧に残ること" do
        post place_visits_path(place), params: params
        expect(stock_names).to eq(%w[江ノ島])
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

    context "ログイン済みで他のグループの場所の場合" do
      let(:other_place) { create(:place, group: create(:user).group) }

      before { sign_in user }

      it "404 を返し、記録しないこと", :aggregate_failures do
        expect { post place_visits_path(other_place), params: valid_params }.not_to change(Visit, :count)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq(Rails.public_path.join("404.html").read)
        expect(flash[:alert]).to be_nil
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
        create(:visit, place: create(:place, group: create(:user).group, name: "他人の場所"))
        sign_in user
        get visits_path
      end

      it "自分のグループの記録だけを訪問日の新しい順に表示すること", :aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(items.map { |item| item.at_css(".fw-bold").text }).to eq(%w[駅前のカフェ 近所の公園 江ノ島])
        expect(response.body).not_to include("他人の場所")
      end

      it "場所の名前・一言・距離感・訪問日・また行きたいかを表示すること", :aggregate_failures do
        item = items.find { |li| li.at_css(".fw-bold").text == "江ノ島" }
        expect(item.text).to include("夕日を見に行きたい", "日帰り", "2026/10/01", "はい")
        cafe = items.find { |li| li.at_css(".fw-bold").text == "駅前のカフェ" }
        expect(cafe.at_css(".want-again").text).to include("いいえ")
      end

      it "各行に確認ダイアログ付きの取り消しボタンを表示すること", :aggregate_failures do
        form = items.first.at_css("form[data-turbo-confirm]")
        expect(form.to_h).to include("action" => visit_path(Visit.find_by!(place: Place.find_by!(name: "駅前のカフェ"))),
                                     "data-turbo-confirm" => "駅前のカフェの訪問記録を取り消しますか？")
        expect(form.at_css("input[name='_method']")["value"]).to eq("delete")
        expect(form.at_css("button").text).to eq("取り消す")
      end

      it "見出しとストック一覧へのリンクを表示すること", :aggregate_failures do
        expect(response.parsed_body.at_css("h1").text).to eq("訪問済み")
        expect(response.parsed_body.at_css("main a[href='#{places_path}']")).to be_present
      end
    end

    context "ログイン済みで訪問記録が1件もない場合" do
      before do
        create(:visit, place: create(:place, group: create(:user).group))
        sign_in user
      end

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

      it "303 で訪問済み一覧にリダイレクトし、完了メッセージを表示すること", :aggregate_failures do
        delete visit_path(visit)
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(visits_path)
        follow_redirect!
        expect(response.body).to include("江ノ島の訪問記録を取り消しました")
      end

      it "「いいえ」の記録を取り消すと、ストックに戻ること", :aggregate_failures do
        expect(stock_names).to be_empty
        delete visit_path(visit)
        expect(stock_names).to eq(%w[江ノ島])
      end
    end

    context "ログイン済みで他のグループの記録の場合" do
      let!(:other_visit) { create(:visit, place: create(:place, group: create(:user).group)) }

      before { sign_in user }

      it "404 を返し、記録を消さないこと", :aggregate_failures do
        expect { delete visit_path(other_visit) }.not_to change(Visit, :count)
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq(Rails.public_path.join("404.html").read)
        expect(flash[:alert]).to be_nil
      end
    end
  end
end
