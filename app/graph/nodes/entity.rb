module Nodes
  class Entity
    include ActiveGraph::Node

    property :name
    property :summary
    property :entity_type
    property :collection, type: Integer
    property :collection_name

    validates :name, presence: true
    validates :entity_type, presence: true

    has_many :out, :relations_to, rel_class: "Relationships::RelatesTo", model_class: "Nodes::Entity",
      unique: { on: [:description] }
    has_many :in, :relations_from, rel_class: "Relationships::RelatesTo", model_class: "Nodes::Entity",
      unique: { on: [:description] }

    self.mapped_label_name = "Nodes::Entity"

    def self.from_model(entity)
      new(
        name: entity.name,
        summary: entity.summary,
        entity_type: entity.entity_type,
        collection: entity.collection.id,
        collection_name: entity.collection.name
      )
    end
  end
end
