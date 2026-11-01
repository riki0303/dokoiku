# frozen_string_literal: true

class PlacePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def create?
    user.present? && user.group_ids.include?(record.group_id)
  end

  class Scope < ApplicationPolicy::Scope
    # 自分が所属するグループの場所だけを返す
    def resolve
      return scope.none if user.nil?

      scope.where(group_id: user.group_ids)
    end
  end
end
