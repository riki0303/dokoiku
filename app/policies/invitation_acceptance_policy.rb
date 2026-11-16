# frozen_string_literal: true

# 招待リンクを開いた側の画面。モデルを持たない headless ポリシー（`authorize :invitation_acceptance, :show?`）。
# リンクを知っていればどのグループの人でも開けるため、ログインしているかだけを見る（招待が使えるかはコントローラーで出し分ける）
class InvitationAcceptancePolicy < ApplicationPolicy
  def show?
    logged_in?
  end
end
