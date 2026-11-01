class Place < ApplicationRecord
  belongs_to :group

  # 主観的な遠さのラベル。距離・所要時間の数値は持たず、DB には文字列で保存する
  enum :distance, %i[near day_trip far].index_with(&:to_s)

  validates :name, presence: true, length: { maximum: 100 }
  validates :note, presence: true, length: { maximum: 200 }
  validates :distance, presence: true
end
