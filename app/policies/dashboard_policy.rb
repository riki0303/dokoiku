# frozen_string_literal: true

# モデルを持たない headless ポリシー（`authorize :dashboard, :show?`）
class DashboardPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
