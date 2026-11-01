require "rails_helper"

RSpec.describe "Places", type: :request do
  let(:user) { create(:user) }
  let(:valid_params) { { place: { name: "江ノ島", note: "夕日を見に行きたい", distance: "day_trip" } } }

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
