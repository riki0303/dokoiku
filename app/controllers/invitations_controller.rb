# 招待リンクを発行する側の画面
class InvitationsController < ApplicationController
  def new
    @invitation = current_group.invitations.build(inviter: current_user)
    authorize @invitation
  end

  # 発行したリンクはその場で render せず show へリダイレクトする（Turbo はフォーム送信後にリダイレクトを求めるため）
  def create
    @invitation = current_group.invitations.build(inviter: current_user)
    authorize @invitation
    @invitation.save!
    redirect_to @invitation, status: :see_other
  end

  # 他のグループの招待は authorize（InvitationPolicy）で拒否する（ApplicationController#user_not_authorized で 404 を返す）
  def show
    @invitation = Invitation.find(params[:id])
    authorize @invitation
  end
end
