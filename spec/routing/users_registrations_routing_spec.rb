require "rails_helper"

RSpec.describe "Users registrations routing", type: :routing do
  it "routes the registration actions", :aggregate_failures do
    expect(get: "/users/sign_up").to route_to("devise/registrations#new")
    expect(post: "/users").to route_to("devise/registrations#create")
    expect(get: "/users/edit").to route_to("devise/registrations#edit")
    expect(put: "/users").to route_to("devise/registrations#update")
    expect(patch: "/users").to route_to("devise/registrations#update")
  end

  it "does not route account deletion" do
    expect(delete: "/users").not_to be_routable
  end

  it "does not route registration cancel" do
    expect(get: "/users/cancel").not_to be_routable
  end
end
