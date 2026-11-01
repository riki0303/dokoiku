require "rails_helper"

RSpec.describe PlacePolicy do
  subject(:policy) { described_class.new(user, place) }

  let(:owner) { create(:user) }
  let(:place) { build(:place, group: owner.group) }

  context "自分のグループの場所の場合" do
    let(:user) { owner }

    it { expect(policy.create?).to be(true) }
    it { expect(policy.new?).to be(true) }
  end

  context "他のグループの場所の場合" do
    let(:user) { create(:user) }

    it { expect(policy.create?).to be(false) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.create?).to be(false) }
  end
end
