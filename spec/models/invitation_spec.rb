require "rails_helper"

RSpec.describe Invitation, type: :model do
  describe "作成時" do
    let(:invitation) { create(:invitation) }

    it "トークンが自動で入ること" do
      expect(invitation.token).to be_present
    end

    it "招待ごとに別のトークンになること" do
      expect(invitation.token).not_to eq(create(:invitation).token)
    end

    it "有効期限が72時間後に入ること" do
      freeze_time do
        expect(invitation.expires_at).to eq(72.hours.from_now)
      end
    end
  end

  describe "#usable?" do
    # travel_to は秒未満を切り捨てるため、有効期限も秒ちょうどにしておく（ちょうどの時刻に移動できるように）
    let(:invitation) { create(:invitation, expires_at: 1.day.from_now.change(usec: 0)) }

    it "未使用で期限内なら true であること" do
      expect(invitation.usable?).to be(true)
    end

    it "使用済みなら false であること" do
      invitation.update!(used_at: Time.current)
      expect(invitation.usable?).to be(false)
    end

    it "有効期限の1秒前なら true であること" do
      travel_to(invitation.expires_at - 1.second) do
        expect(invitation.usable?).to be(true)
      end
    end

    it "有効期限ちょうどなら false であること" do
      travel_to(invitation.expires_at) do
        expect(invitation.usable?).to be(false)
      end
    end
  end

  describe "アソシエーション" do
    let!(:invitation) { create(:invitation) }

    it "招待したグループと招待した人を取得できること", :aggregate_failures do
      expect(invitation.group.invitations).to contain_exactly(invitation)
      expect(invitation.inviter.sent_invitations).to contain_exactly(invitation)
    end

    it "グループを削除すると招待も削除されること" do
      expect { invitation.group.destroy }.to change(described_class, :count).by(-1)
    end

    it "招待した人を削除すると招待も削除されること" do
      expect { invitation.inviter.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
