class Entity < ApplicationRecord
  has_many :entity_descriptions, dependent: :destroy
  has_many :relationships_from, dependent: :destroy, class_name: 'Relationship', foreign_key: :from_id
  has_many :relationships_to, dependent: :destroy, class_name: 'Relationship', foreign_key: :to_id
end
