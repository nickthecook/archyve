class CollectionMembership < ApplicationRecord
  belongs_to :collection
  belongs_to :document

  # How the document came to be in the collection.
  enum :source, {
    connector: "connector",  # auto-joined because a connector feeds this collection
    manual: "manual"                    # explicitly added by a user
  }

  scope :active, -> { where(removed_at: nil) }
  scope :removed, -> { where.not(removed_at: nil) }

  validates :document_id, uniqueness: { scope: :collection_id }

  def active?
    removed_at.nil?
  end

  def remove!
    update!(removed_at: Time.current)
  end

  def restore!
    update!(removed_at: nil)
  end
end
