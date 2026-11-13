class Group < ApplicationRecord
  has_many :group_users, dependent: :destroy
  has_many :users, through: :group_users

  has_many :collection_groups, dependent: :destroy
  has_many :source_groups, dependent: :destroy

  normalizes :name, with: -> { it.strip }

  validates :name, presence: true, uniqueness: true
end
