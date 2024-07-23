module Relationships
  class RelatesTo
    include ActiveGraph::Relationship

    from_class :"Nodes::Entity"
    to_class :"Nodes::Entity"

    property :description

    validates :description, presence: true
  end
end
