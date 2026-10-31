require "rails_helper"

RSpec.describe User, type: :model do
  describe "バリデーション" do
    subject(:user) { build(:user) }

    it "正しい属性なら有効であること" do
      expect(user).to be_valid
    end

    describe "name" do
      it "必須であること", :aggregate_failures do
        user.name = ""
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("を入力してください")
      end

      it "50文字なら有効であること" do
        user.name = "あ" * 50
        expect(user).to be_valid
      end

      it "51文字なら無効であること", :aggregate_failures do
        user.name = "あ" * 51
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("は50文字以内で入力してください")
      end
    end

    describe "email" do
      it "必須であること", :aggregate_failures do
        user.email = ""
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("を入力してください")
      end

      it "大文字・小文字を区別せず一意であること", :aggregate_failures do
        create(:user, email: "taken@example.com")
        user.email = "TAKEN@example.com"
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("はすでに存在します")
      end
    end
  end

  describe "グループ" do
    it "作成時に1人グループと membership を作成すること" do
      expect { create(:user) }
        .to change(Group, :count).by(1)
        .and change(Membership, :count).by(1)
    end

    it "作成したグループに自分だけが所属すること" do
      user = create(:user)
      expect(user.group.users).to contain_exactly(user)
    end

    it "group で所属グループを返すこと" do
      user = create(:user)
      expect(user.group).to eq(Membership.find_by!(user: user).group)
    end

    it "更新時にはグループを追加で作成しないこと" do
      user = create(:user)
      expect { user.update!(name: "新しい名前") }.not_to change(Group, :count)
    end

    context "グループの保存に失敗した場合" do
      let(:group) { Group.new }

      before do
        allow(Group).to receive(:new).and_return(group)
        allow(group).to receive(:save).and_raise(ActiveRecord::StatementInvalid, "groups の保存に失敗")
      end

      it "ユーザーも membership も作成されないこと" do
        expect { build(:user).save }
          .to raise_error(ActiveRecord::StatementInvalid)
          .and not_change(described_class, :count)
          .and not_change(Membership, :count)
      end
    end

    context "削除した場合" do
      let!(:user) { create(:user) }

      it "membership は削除され、グループは残ること" do
        expect { user.destroy }
          .to change(Membership, :count).by(-1)
          .and not_change(Group, :count)
      end
    end
  end
end
