class Entity < ApplicationRecord
  has_many :entity_descriptions, dependent: :destroy
end
