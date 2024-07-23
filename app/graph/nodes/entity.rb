module Nodes
  class Entity
    include ActiveGraph::Node

    property :name
    property :description
    property :entity_type

    validates :name, presence: true
    validates :entity_type, presence: true

    has_many :out, :relations_to, rel_class: "Relationships::RelatesTo", model_class: "Entity"
    has_many :in, :relations_from, rel_class: "Relationships::RelatesTo", model_class: "Entity"

    self.mapped_label_name = "Entity"
  end
end
