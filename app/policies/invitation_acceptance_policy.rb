# frozen_string_literal: true

# 招待リンクを開いた側の画面と参加処理。モデルを持たない headless ポリシー（`authorize :invitation_acceptance, :show?`）。
# リンクを知っていればどのグループの人でも開ける・参加できるため、ログインしているかだけを見る
# （招待が使えるか・参加できる人かはコントローラーで出し分ける。404 にすると理由が伝わらないため）
class InvitationAcceptancePolicy < ApplicationPolicy
  def show?
    logged_in?
  end

  def create?
    logged_in?
  end
end
