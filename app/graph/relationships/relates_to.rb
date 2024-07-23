module Relationships
  class RelatesTo
    include ActiveGraph::Relationship

    from_class :"Nodes::Entity"
    to_class :"Nodes::Entity"

    property :description
    property :document, type: Integer
    property :document_filename
    property :chunk, type: Integer

    creates_unique on: [:description]

    validates :description, presence: true
  end
end
