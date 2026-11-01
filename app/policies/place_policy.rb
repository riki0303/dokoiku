# frozen_string_literal: true

class PlacePolicy < ApplicationPolicy
  def create?
    user.present? && user.group_ids.include?(record.group_id)
  end
end
