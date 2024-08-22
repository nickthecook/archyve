class GraphEntityDescription < ApplicationRecord
  belongs_to :graph_entity
  belongs_to :chunk
  has_one :collection, through: :graph_entity
end
