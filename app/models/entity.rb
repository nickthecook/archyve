class Entity < ApplicationRecord
  has_many :entity_descritions, dependent: :destroy
end
