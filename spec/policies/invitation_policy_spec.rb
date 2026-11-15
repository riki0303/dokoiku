require "rails_helper"

RSpec.describe InvitationPolicy do
  subject(:policy) { described_class.new(user, invitation) }

  let(:owner) { create(:user) }
  let(:invitation) { build(:invitation, inviter: owner) }

  context "自分のグループの招待の場合" do
    let(:user) { owner }

    it { expect(policy.new?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.show?).to be(true) }
  end

  context "同じグループの、発行者以外のメンバーの場合" do
    # membership の factory で関連の user を作ると個人グループにも所属するため、
    # 招待のグループ（owner の個人グループ）に明示的に入れる。user.group は個人グループを返すが、ポリシーは group_ids で判定する
    let(:user) { create(:user).tap { |member| create(:membership, user: member, group: owner.group) } }

    it { expect(policy.create?).to be(true) }
    it { expect(policy.show?).to be(true) }
  end

  context "他のグループの招待の場合" do
    let(:user) { create(:user) }

    it { expect(policy.new?).to be(false) }
    it { expect(policy.create?).to be(false) }
    it { expect(policy.show?).to be(false) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.new?).to be(false) }
    it { expect(policy.create?).to be(false) }
    it { expect(policy.show?).to be(false) }
  end
end
