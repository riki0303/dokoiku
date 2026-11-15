FactoryBot.define do
  # group は inviter の個人グループにする（inviter が所属していないグループへの招待にならないように）。
  # user の個人グループは保存時に作られるため、build(:invitation) でも inviter は保存する
  factory :invitation do
    association :inviter, factory: :user, strategy: :create
    group { inviter.group }
  end
end
