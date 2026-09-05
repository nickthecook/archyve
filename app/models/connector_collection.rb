class ConnectorCollection < ApplicationRecord
  belongs_to :connector
  belongs_to :collection

  validates :connector_id, uniqueness: { scope: :collection_id }
end
