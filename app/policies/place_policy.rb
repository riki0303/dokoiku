# frozen_string_literal: true

class PlacePolicy < ApplicationPolicy
  def index?
    logged_in?
  end

  def create?
    logged_in? &&user.group_ids.include?(record.group_id)
  end

  # 編集・削除も登録と同じく、自分のグループの場所だけを対象にする
  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope < ApplicationPolicy::Scope
    # 自分が所属するグループの場所だけを返す
    def resolve
      return scope.none if user.nil?

      scope.where(group_id: user.group_ids)
    end
  end
end
