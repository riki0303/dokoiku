# 招待リンクを開いた側の画面。リンクの状態と開いた人によって、使えない／参加済み／参加の確認を出し分ける
class InvitationAcceptancesController < ApplicationController
  def show
    authorize :invitation_acceptance, :show?
    @invitation = Invitation.find_by(token: params[:token])

    if @invitation.nil? || !@invitation.usable?
      # 存在しないトークンと使用済み・期限切れを区別させないよう、どれも同じ画面・同じ 404 にする
      render :unusable, status: :not_found
    elsif current_user.group_ids.include?(@invitation.group_id)
      # すでにメンバーなら参加済みと伝えるだけにする（リンクは使用済みにしない）
      render :joined
    else
      # 参加すると今のグループの場所が消化済みも含めてすべて移るため、件数は全件で数える
      @places_count = current_group.places.count
    end
  end
end
