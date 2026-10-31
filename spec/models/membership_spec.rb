require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "バリデーション" do
    let(:user) { create(:user) }
    let(:group) { create(:group) }

    it "正しい属性なら有効であること" do
      expect(build(:membership, user: user, group: group)).to be_valid
    end

    describe "user と group の組み合わせ" do
      before { create(:membership, user: user, group: group) }

      it "同じ組み合わせは重複できないこと", :aggregate_failures do
        membership = build(:membership, user: user, group: group)
        expect(membership).not_to be_valid
        expect(membership.errors[:user_id]).to include("はすでに存在します")
      end

      it "バリデーションを通さなくても DB 制約で重複を防ぐこと" do
        membership = build(:membership, user: user, group: group)
        expect { membership.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "別のグループなら同じユーザーでも有効であること" do
        expect(build(:membership, user: user, group: create(:group))).to be_valid
      end
    end
  end
end
