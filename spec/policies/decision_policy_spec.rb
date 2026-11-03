require "rails_helper"

RSpec.describe DecisionPolicy do
  subject(:policy) { described_class.new(user, :decision) }

  context "ログイン済みの場合" do
    let(:user) { build(:user) }

    it { expect(policy.show?).to be(true) }
    it { expect(policy.redraw?).to be(true) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.show?).to be(false) }
    it { expect(policy.redraw?).to be(false) }
  end
end
