# frozen_string_literal: true

# モデルを持たない headless ポリシー（`authorize :decision, :show?`）
class DecisionPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  # 「別の3件」も、画面を見られる人なら押せる
  def redraw?
    show?
  end
end
