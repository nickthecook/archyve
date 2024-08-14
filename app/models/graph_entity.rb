class GraphEntity < ApplicationRecord
  has_many :descriptions, dependent: :destroy, class_name: 'GraphEntityDescription'
  has_many :relationships_from, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :from_entity
  has_many :relationships_to, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :to_entity
  belongs_to :collection

  def graph_node
    Nodes::Entity.find_by(attributes.slice(*entity_find_attrs))
  end

  private

  def entity_find_attrs
    %w[name entity_type collection collection_name]
  end
end
