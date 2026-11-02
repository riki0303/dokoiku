class Place < ApplicationRecord
  belongs_to :group

  # 主観的な遠さのラベル。距離・所要時間の数値は持たず、DB には文字列で保存する
  # 一覧にない値（"xxx" など）は例外ではなくバリデーションエラーにする。
  # 未選択は下の presence で「入力してください」を出すため、ここでは nil を対象外にしてエラーの重複を避ける
  enum :distance, %i[near day_trip far].index_with(&:to_s), validate: { allow_nil: true }

  validates :name, presence: true, length: { maximum: 100 }
  validates :note, presence: true, length: { maximum: 200 }
  validates :distance, presence: true

  # ransack で URL から絞り込める項目の許可リスト。距離感だけを許可し、並び替えはさせない（関連の検索は ApplicationRecord で禁止済み）
  def self.ransackable_attributes(_auth_object = nil)
    %w[distance]
  end

  def self.ransortable_attributes(_auth_object = nil)
    []
  end
end
