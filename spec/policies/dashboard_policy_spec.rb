require "rails_helper"

RSpec.describe DashboardPolicy do
  subject(:policy) { described_class.new(user, :dashboard) }

  context "when a user is signed in" do
    let(:user) { build(:user) }

    it { expect(policy.show?).to be(true) }
  end

  context "when no user is signed in" do
    let(:user) { nil }

    it { expect(policy.show?).to be(false) }
  end
end
