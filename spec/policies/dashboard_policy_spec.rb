require "rails_helper"

RSpec.describe DashboardPolicy do
  subject(:policy) { described_class.new(user, :dashboard) }

  context "ログイン済みの場合" do
    let(:user) { build(:user) }

    it { expect(policy.show?).to be(true) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.show?).to be(false) }
  end
end
