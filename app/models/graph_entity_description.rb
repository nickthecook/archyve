class GraphEntityDescription < ApplicationRecord
  belongs_to :graph_entity
  belongs_to :chunk
end
