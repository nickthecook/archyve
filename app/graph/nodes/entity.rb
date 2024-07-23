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

    has_many :out, :relations_to, rel_class: "Relationships::RelatesTo", model_class: "Nodes::Entity"
    has_many :in, :relations_from, rel_class: "Relationships::RelatesTo", model_class: "Nodes::Entity"

    self.mapped_label_name = "Nodes::Entity"
  end
end
