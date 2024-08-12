class GraphRelationship < ApplicationRecord
  belongs_to :from_entity, class_name: "GraphEntity"
  belongs_to :to_entity, class_name: "GraphEntity"
  belongs_to :chunk

  # TODO: validate that to and from entities belong to the same collection
end
