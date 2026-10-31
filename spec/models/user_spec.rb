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
end
