require "rails_helper"

RSpec.describe "PWA マニフェスト", type: :request do
  describe "GET /manifest.json" do
    context "未ログインの場合" do
      let(:expected_manifest) do
        {
          "name" => "Dokoiku",
          "short_name" => "Dokoiku",
          "description" => "行きたい場所の中から、今日行く場所を決める",
          "theme_color" => "#212529",
          "background_color" => "#ffffff",
          "start_url" => "/",
          "display" => "standalone",
          "scope" => "/"
        }
      end

      before { get pwa_manifest_path(format: :json) }

      it "200 を返すこと" do
        expect(response).to have_http_status(:ok)
      end

      it "アプリの名前や色などの情報を返すこと" do
        expect(JSON.parse(response.body)).to include(expected_manifest)
      end
    end
  end
end
