class GraphEntity < ApplicationRecord
  has_many :descriptions, dependent: :destroy, class_name: 'GraphEntityDescription'
  has_many :relationships_from, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :from_entity
  has_many :relationships_to, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :to_entity
  belongs_to :collection
end
