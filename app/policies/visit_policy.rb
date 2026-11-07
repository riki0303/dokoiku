# frozen_string_literal: true

class VisitPolicy < ApplicationPolicy
  def index?
    logged_in?
  end

  # 自分のグループの場所にだけ訪問を記録できる
  def create?
    logged_in? && user.group_ids.include?(record.place.group_id)
  end

  # 取り消しも記録と同じく、自分のグループの場所の記録だけを対象にする
  def destroy?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    # 自分が所属するグループの場所に付いた訪問記録だけを返す
    def resolve
      return scope.none if user.nil?

      scope.joins(:place).where(places: { group_id: user.group_ids })
    end
  end
end
