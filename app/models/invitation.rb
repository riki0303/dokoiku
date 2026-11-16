# グループへの招待リンク。リンクは1回使うと無効になり、使われなくても発行から72時間で無効になる
class Invitation < ApplicationRecord
  EXPIRES_IN = 72.hours

  belongs_to :group
  belongs_to :inviter, class_name: "User"

  # 参加の確認画面で招待した人の名前を出すため（invitation.inviter_name のように呼ぶ）
  delegate :name, to: :inviter, prefix: true

  # 推測できないランダムな文字列を URL に使う（id だと連番から他の招待を開けてしまうため）
  has_secure_token :token

  before_validation :set_expires_at, on: :create

  # 参加に使えるか。使用済み・期限切れのリンクは使えない
  def usable?
    used_at.nil? && expires_at.future?
  end

  private

  def set_expires_at
    self.expires_at ||= EXPIRES_IN.from_now
  end
end
