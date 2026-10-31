require "rails_helper"

RSpec.describe "ユーザー登録のルーティング", type: :routing do
  it "登録関連のアクションにルーティングすること", :aggregate_failures do
    expect(get: "/users/sign_up").to route_to("devise/registrations#new")
    expect(post: "/users").to route_to("devise/registrations#create")
    expect(get: "/users/edit").to route_to("devise/registrations#edit")
    expect(put: "/users").to route_to("devise/registrations#update")
    expect(patch: "/users").to route_to("devise/registrations#update")
  end

  it "アカウント削除にルーティングしないこと" do
    expect(delete: "/users").not_to be_routable
  end

  it "登録キャンセルにルーティングしないこと" do
    expect(get: "/users/cancel").not_to be_routable
  end
end
