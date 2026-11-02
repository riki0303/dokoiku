require "rails_helper"

RSpec.describe PlacePolicy do
  subject(:policy) { described_class.new(user, place) }

  let(:owner) { create(:user) }
  let(:place) { build(:place, group: owner.group) }

  context "自分のグループの場所の場合" do
    let(:user) { owner }

    it { expect(policy.index?).to be(true) }
    it { expect(policy.create?).to be(true) }
    it { expect(policy.new?).to be(true) }
    it { expect(policy.edit?).to be(true) }
    it { expect(policy.update?).to be(true) }
    it { expect(policy.destroy?).to be(true) }
  end

  context "他のグループの場所の場合" do
    let(:user) { create(:user) }

    it { expect(policy.create?).to be(false) }
    it { expect(policy.edit?).to be(false) }
    it { expect(policy.update?).to be(false) }
    it { expect(policy.destroy?).to be(false) }
  end

  context "未ログインの場合" do
    let(:user) { nil }

    it { expect(policy.index?).to be(false) }
    it { expect(policy.create?).to be(false) }
    it { expect(policy.edit?).to be(false) }
    it { expect(policy.update?).to be(false) }
    it { expect(policy.destroy?).to be(false) }
  end

  describe "Scope" do
    subject(:resolved) { described_class::Scope.new(user, Place).resolve }

    let!(:own_place) { create(:place, group: owner.group) }

    before { create(:place, group: create(:user).group) }

    context "ログイン済みの場合" do
      let(:user) { owner }

      it "自分のグループの場所だけを返すこと" do
        expect(resolved).to contain_exactly(own_place)
      end
    end

    context "未ログインの場合" do
      let(:user) { nil }

      it "何も返さないこと" do
        expect(resolved).to be_empty
      end
    end
  end
end
