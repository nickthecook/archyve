class EntityDescription < ApplicationRecord
  belongs_to :entity
  belongs_to :chunk
end
