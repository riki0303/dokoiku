# グループへの招待リンク。リンクは1回使うと無効になり、使われなくても発行から72時間で無効になる
class Invitation < ApplicationRecord
  EXPIRES_IN = 72.hours

  # 招待を使って参加できないときの例外。reason で理由を区別し、コントローラーで表示を出し分ける
  #   :unusable       使用済み・期限切れ
  #   :already_member すでに参加先のメンバー
  #   :other_members  今のグループにほかのメンバーがいる
  # 結果オブジェクトを返すのではなく例外にするのは、accept! のトランザクションをそのままロールバックさせるため
  class NotAcceptable < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("invitation is not acceptable: #{reason}")
    end
  end

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

  # user がこの招待で参加できない理由（NotAcceptable の reason と同じ Symbol）。参加できるなら nil。
  # 確認画面の出し分けと accept! のロック後の再確認で同じ判定を使うため、ここにまとめる。
  # 判定順は「使えない」→「すでにメンバー」→「ほかのメンバーがいる」（使えないリンクでは、メンバーかどうかも伝えないため）
  def unacceptable_reason(user)
    return :unusable unless usable?
    return :already_member if group.memberships.exists?(user_id: user.id)

    :other_members if user.group.other_members?(user)
  end

  # user を招待先のグループに参加させる。今のグループの場所（訪問記録を含む）を参加先へ移してから、今のグループを削除する。
  # 参加できなければ NotAcceptable を投げ、何も変えない（トランザクションごとロールバックする）
  def accept!(user)
    transaction do
      # ロックは「本人 → グループ（id 順）→ 招待」の順に取る。どの参加処理もこの順で取るので、互いに待ち合ってデッドロックすることがない。
      # 招待を先にロックすると、今のグループを削除するとき（dependent で今のグループの招待を DELETE する）に
      # その招待を使おうとしている別の人の参加処理と、招待とグループのロックを逆順に待ち合ってしまう
      #
      # 同じ人が別々のリンクで同時に参加すると、今のグループ（user.group）が途中で消えて移し先がずれるため、まず本人の行をロックする
      user.lock!
      old_group = user.group
      # 今のグループに誰かが同時に参加する／参加先に同時に誰かが入るケースで判定がずれないよう、両方のグループの行をロックする。
      # 2つの参加処理が互いに相手のグループを待つデッドロックを避けるため、id 順に取る（招待の group_id は変わらないので読み直さなくてよい）
      Group.where(id: [ old_group.id, group_id ]).order(:id).lock.load
      # 同じリンクの同時使用で1回だけ成功させるため、招待の行をロックしてから使えるかを確かめ直す（lock! は最新の値で読み直す）
      lock_for_acceptance!

      reason = unacceptable_reason(user)
      raise NotAcceptable, reason if reason

      # 訪問記録は場所に紐づいているので、場所を移せば一緒に移る。
      # コールバック・バリデーションの対象がない group_id の付け替えだけなので、1件ずつ保存せず一括で更新する
      Place.where(group_id: old_group.id).update_all(group_id: group_id) # rubocop:disable Rails/SkipsModelValidations
      # 場所を移したあとに削除するので、dependent で消えるのはメンバーシップと今のグループの招待だけになる
      old_group.destroy!
      group.memberships.create!(user: user)
      update!(used_at: Time.current)
    end
  end

  private

  # 招待の行をロックして読み直す。待っている間に招待が消えた（発行した人のグループが参加で削除された・退会した）場合は、
  # 使用済み・期限切れと同じく「使えない」として扱う
  def lock_for_acceptance!
    lock!
  rescue ActiveRecord::RecordNotFound
    raise NotAcceptable, :unusable
  end

  def set_expires_at
    self.expires_at ||= EXPIRES_IN.from_now
  end
end
