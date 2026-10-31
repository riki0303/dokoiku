class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  validates :name, presence: true, length: { maximum: 50 }
end
