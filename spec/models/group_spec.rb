require "rails_helper"

RSpec.describe Group, type: :model do
  describe "アソシエーション" do
    let(:group) { create(:group) }
    let(:user) { create(:user) }

    before { create(:membership, user: user, group: group) }

    it "membership を通じて所属ユーザーを取得できること", :aggregate_failures do
      expect(group.memberships.count).to eq(1)
      expect(group.users).to contain_exactly(user)
    end

    it "削除すると membership も削除されること", :aggregate_failures do
      expect { group.destroy }.to change(Membership, :count).by(-1)
      expect(user.reload.groups).not_to include(group)
    end
  end
end
