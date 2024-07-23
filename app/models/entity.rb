class Entity < ApplicationRecord
  has_many :descriptions, dependent: :destroy, class_name: 'EntityDescription'
  has_many :relationships_from, dependent: :destroy, class_name: 'Relationship', inverse_of: :from
  has_many :relationships_to, dependent: :destroy, class_name: 'Relationship', inverse_of: :to
  belongs_to :collection
end
