class SourceCollection < ApplicationRecord
  belongs_to :source
  belongs_to :collection

  validates :source_id, uniqueness: { scope: :collection_id }
end
