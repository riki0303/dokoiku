# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  # 自分のグループへの招待だけを発行できる
  def create?
    logged_in? && user.group_ids.include?(record.group_id)
  end

  # 発行したリンクは、同じグループのメンバーなら見られる（他のグループの招待は見つからない扱いにする）
  def show?
    create?
  end
end
