require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject(:user) { build(:user) }

    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    describe "name" do
      it "is required", :aggregate_failures do
        user.name = ""
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("を入力してください")
      end

      it "is valid with 50 characters" do
        user.name = "あ" * 50
        expect(user).to be_valid
      end

      it "is invalid with 51 characters", :aggregate_failures do
        user.name = "あ" * 51
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("は50文字以内で入力してください")
      end
    end

    describe "email" do
      it "is required", :aggregate_failures do
        user.email = ""
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("を入力してください")
      end

      it "must be unique (case-insensitive)", :aggregate_failures do
        create(:user, email: "taken@example.com")
        user.email = "TAKEN@example.com"
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("はすでに存在します")
      end
    end
  end
end
