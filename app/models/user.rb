class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships

  validates :name, presence: true, length: { maximum: 50 }

  before_validation :build_personal_group, on: :create

  # 現状は1人1グループの前提（段階4の招待機能で複数所属を扱う際に見直す）
  def group
    groups.first
  end

  private

  # サインアップ時に1人グループを組み立てる。has_many の autosave により user の保存と同じトランザクションで保存される
  def build_personal_group
    return if memberships.any?

    memberships.build(group: Group.new)
  end
end
