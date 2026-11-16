# 招待リンクを開いた側の画面と参加処理。リンクの状態と開いた人によって、使えない／参加済み／参加できない／参加の確認を出し分ける
class InvitationAcceptancesController < ApplicationController
  before_action :set_invitation

  def show
    authorize :invitation_acceptance, :show?
    reason = unacceptable_reason
    return render_unacceptable(reason) if reason

    # 参加すると今のグループの場所が消化済みも含めてすべて移るため、件数は全件で数える。
    # 移すのは今のグループ（current_group）の場所なので、所属グループ全体を返す policy_scope ではなく current_group から数える
    @places_count = current_group.places.count
  end

  # 「参加する」ボタン。確認画面を開いてから押すまでの間にリンクが使われた・状況が変わった場合もあるため、show と同じ判定をやり直す
  def create
    authorize :invitation_acceptance, :create?
    reason = unacceptable_reason
    return render_unacceptable(reason, submitted: true) if reason

    @invitation.accept!(current_user)
    # 参加先の場所が見られることを伝えるため、行きたい場所一覧へ移る（Turbo はフォーム送信後にリダイレクトを求めるため 303）
    redirect_to places_path, notice: "#{@invitation.inviter_name}さんのグループに参加しました", status: :see_other
  rescue Invitation::NotAcceptable => e
    # 上の判定のあと、ロックを取るまでの間に同じリンクが使われた・誰かが今のグループに入った場合も同じ表示にする
    render_unacceptable(e.reason, submitted: true)
  end

  private

  def set_invitation
    @invitation = Invitation.find_by(token: params[:token])
  end

  # 存在しないトークンは使用済み・期限切れと区別させないよう、同じ :unusable として扱う
  def unacceptable_reason
    return :unusable if @invitation.nil?

    @invitation.unacceptable_reason(current_user)
  end

  # submitted: 「参加する」ボタンから送られた（create）か。開いただけ（show）とはステータスや返し方を変える
  def render_unacceptable(reason, submitted: false)
    case reason
    when :unusable
      # 存在しないトークンと使用済み・期限切れを区別させないよう、どれも同じ画面・同じ 404 にする
      render :unusable, status: :not_found
    when :already_member
      # すでにメンバーなら参加済みと伝えるだけにする（リンクは使用済みにしない）。
      # ボタンから送られたときは Turbo が 2xx の render を表示しないため、GET の画面へリダイレクトして参加済みを表示する
      if submitted
        redirect_to invitation_acceptance_path(params[:token]), status: :see_other
      else
        render :joined
      end
    when :other_members
      # 今のグループを削除するとほかのメンバーが巻き込まれるため参加させない。理由を見せるため 404 にはせず画面で伝える
      render :cannot_join, status: submitted ? :unprocessable_content : :ok
    end
  end
end
