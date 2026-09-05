# STI base class. Concrete sources live in app/models/connectors/* and set
# their own behaviour (list / fetch). ManualUpload is the first.
class Connector < ApplicationRecord
  has_many :connector_collections, dependent: :destroy
  has_many :collections, through: :connector_collections
  has_many :documents, dependent: :destroy

  validates :name, presence: true

  # Collections this connector feeds — produced documents auto-join these.
  def fed_collections
    collections
  end
end
