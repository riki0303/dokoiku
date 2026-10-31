FactoryBot.define do
  # 注意: 関連で作られる user は before_validation で自分の1人グループも持つため、2グループに所属する。
  # また user.group は指定した group ではなく個人グループを返す
  factory :membership do
    user
    group
  end
end
