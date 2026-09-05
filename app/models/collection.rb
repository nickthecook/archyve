class Collection < ApplicationRecord
  has_many :connector_collections, dependent: :destroy
  has_many :connectors, through: :connector_collections

  has_many :collection_memberships, dependent: :destroy
  has_many :active_memberships,
    -> { where(removed_at: nil) },
    class_name: "CollectionMembership"
  has_many :documents, through: :active_memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug, on: :create

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
