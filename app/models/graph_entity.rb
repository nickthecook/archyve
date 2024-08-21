class GraphEntity < ApplicationRecord
  has_many :descriptions, dependent: :destroy, class_name: 'GraphEntityDescription'
  has_many :relationships_from, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :from_entity
  has_many :relationships_to, dependent: :destroy, class_name: 'GraphRelationship', inverse_of: :to_entity
  belongs_to :collection
  has_one :user, through: :collection

  scope :by_description_count, lambda {
    joins(:descriptions).group("graph_entities.id").order(Arel.sql("count(*) desc"))
  }

  scope :by_relationship_count, lambda {
    joins(:relationships_to).joins(:relationships_from).group("graph_entities.id").order(Arel.sql("count(*) desc"))
  }

  after_create_commit lambda {
    broadcast_append_to(
      :collections,
      target: "collection_#{collection.id}_entities",
      partial: "shared/entity",
      locals: {
        entity: self,
      }
    )
  }
  after_update_commit lambda {
    broadcast_replace_to(
      :collections,
      target: "graph_entity_#{id}",
      partial: "shared/entity",
      locals: {
        entity: self,
      }
    )
  }

  def graph_node
    Nodes::Entity.find_by(attributes.slice(*entity_find_attrs))
  end

  def relationship_count
    relationships_from.count + relationships_to.count
  end

  private

  def entity_find_attrs
    %w[name entity_type collection collection_name]
  end
end
