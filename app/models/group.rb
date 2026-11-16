class Group < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :places, dependent: :destroy
  has_many :invitations, dependent: :destroy

  # user 以外のメンバーがいるか。招待で別のグループへ移るとこのグループは削除されるため、
  # ほかのメンバーがいるグループの人は参加させない（巻き込まないように）判定に使う
  def other_members?(user)
    memberships.where.not(user_id: user.id).exists?
  end
end
