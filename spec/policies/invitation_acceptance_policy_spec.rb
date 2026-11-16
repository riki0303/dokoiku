require "rails_helper"

RSpec.describe InvitationAcceptancePolicy do
  subject(:policy) { described_class.new(user, :invitation_acceptance) }

  context "ログイン済みの場合" do
    let(:user) { build(:user) }

    it { expect(policy.show?).to be(true) }
    it { expect(policy.create?).to be(true) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.show?).to be(false) }
    it { expect(policy.create?).to be(false) }
  end
end
