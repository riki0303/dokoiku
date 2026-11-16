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

  describe "#accept!" do
    let(:inviter) { create(:user) }
    let(:invitation) { create(:invitation, inviter: inviter) }
    let(:user) { create(:user) }
    # 参加すると user.group は参加先に変わるため、参加前の今のグループを先に覚えておく
    let!(:old_group) { user.group }
    let!(:moved_place) { create(:place, group: old_group, name: "元のグループの場所") }

    before do
      create(:visit, place: moved_place, want_again: false)
      create(:place, group: inviter.group, name: "参加先の場所")
    end

    context "参加できる場合" do
      it "今のグループの場所が訪問記録ごと参加先へ移ること", :aggregate_failures do
        invitation.accept!(user)
        expect(moved_place.reload.group).to eq(invitation.group)
        expect(moved_place.visits.count).to eq(1)
      end

      it "参加先の場所は参加先に残ること" do
        invitation.accept!(user)
        expect(invitation.group.places.pluck(:name)).to contain_exactly("元のグループの場所", "参加先の場所")
      end

      it "今のグループが削除されること" do
        invitation.accept!(user)
        expect(Group.exists?(old_group.id)).to be(false)
      end

      it "参加先のメンバーになり、所属が参加先だけになること", :aggregate_failures do
        invitation.accept!(user)
        expect(invitation.group.users).to contain_exactly(inviter, user)
        # 1人1グループの前提のまま、User#group が参加先を返すこと
        expect(user.reload.groups).to contain_exactly(invitation.group)
        expect(user.group).to eq(invitation.group)
      end

      it "リンクが使用済みになること" do
        freeze_time do
          invitation.accept!(user)
          expect(invitation.reload.used_at).to eq(Time.current)
        end
      end

      it "今のグループで発行していた招待も削除されること" do
        old_invitation = create(:invitation, inviter: user)
        invitation.accept!(user)
        expect(described_class.exists?(old_invitation.id)).to be(false)
      end
    end

    # 参加できない場合は例外を投げ、場所・グループ・メンバー・リンクのどれも変えないこと
    shared_examples "参加できない" do |reason|
      # 例外を投げることは別の例で確かめるので、変化がないことを見る例では握りつぶす
      def accept_ignoring_error
        invitation.accept!(user)
      rescue described_class::NotAcceptable
        nil
      end

      it "理由つきの NotAcceptable を投げること" do
        expect { invitation.accept!(user) }
          .to raise_error(an_instance_of(described_class::NotAcceptable).and(having_attributes(reason: reason)))
      end

      it "場所・グループ・メンバー・リンクのどれも変えないこと" do
        expect { accept_ignoring_error }
          .to not_change { moved_place.reload.group_id }
          .and(not_change(Group, :count))
          .and(not_change(Membership, :count))
          .and(not_change { invitation.reload.used_at })
      end
    end

    context "使用済みのリンクの場合" do
      before { invitation.update!(used_at: 1.hour.ago) }

      it_behaves_like "参加できない", :unusable
    end

    context "期限切れのリンクの場合" do
      # travel_to は秒未満を切り捨てるため、有効期限も秒ちょうどにしておく
      let(:invitation) { create(:invitation, inviter: inviter, expires_at: 1.day.from_now.change(usec: 0)) }

      around { |example| travel_to(invitation.expires_at) { example.run } }

      it_behaves_like "参加できない", :unusable
    end

    context "すでに参加先のメンバーの場合" do
      let(:user) { inviter }

      it_behaves_like "参加できない", :already_member
    end

    context "今のグループにほかのメンバーがいる場合" do
      before { create(:membership, group: old_group) }

      it_behaves_like "参加できない", :other_members
    end

    # すでにメンバーなら、参加先（＝今のグループ）にほかのメンバーがいても「すでにメンバー」を先に返すこと（判定順）
    context "すでに参加先のメンバーで、参加先にほかのメンバーもいる場合" do
      # inviter 以外のメンバー。別の招待で inviter のグループに参加させ、所属を inviter のグループだけにする
      let(:user) { create(:user).tap { |member| create(:invitation, inviter: inviter).accept!(member) } }

      it_behaves_like "参加できない", :already_member
    end

    # 確認画面を開いたあと、ロックを取るまでの間に同じリンクが別の人に使われた場合（同時使用）。
    # スレッドを使うテストは不安定になりやすいため、手元のオブジェクトが古いままでも lock! で読み直して弾くことを確かめる
    context "読み込んだあとに別の人がリンクを使った場合" do
      before { described_class.find(invitation.id).update!(used_at: Time.current) }

      # 共通の例は変化を見るために invitation を読み直してしまうため、ここでは古いオブジェクトのまま呼ぶ
      it "NotAcceptable を投げ、場所を移さないこと", :aggregate_failures do
        expect(invitation.used_at).to be_nil
        expect { invitation.accept!(user) }
          .to raise_error(an_instance_of(described_class::NotAcceptable).and(having_attributes(reason: :unusable)))
        expect(moved_place.reload.group).to eq(old_group)
        expect(Group.exists?(old_group.id)).to be(true)
      end
    end

    # 本人とグループのロックを待っている間に、招待が消えた場合（発行した人のグループが別の参加で削除された など）
    context "読み込んだあとに招待が削除された場合" do
      before { described_class.where(id: invitation.id).delete_all }

      it "使えないリンクとして NotAcceptable を投げ、場所を移さないこと", :aggregate_failures do
        expect { invitation.accept!(user) }
          .to raise_error(an_instance_of(described_class::NotAcceptable).and(having_attributes(reason: :unusable)))
        expect(moved_place.reload.group).to eq(old_group)
        expect(Group.exists?(old_group.id)).to be(true)
      end
    end
  end
end
