class Document < ApplicationRecord
  belongs_to :source

  # The sync run that last created or updated this document. Optional: manually
  # uploaded documents never had one, and it is nullified when an old run is
  # pruned. It is what lets a run report its own processing progress.
  belongs_to :source_sync, optional: true

  # Raw bytes for the document. For manual_upload this is the user's file; other
  # sources attach whatever they fetched so the pipeline has one input shape.
  has_one_attached :file

  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships
  has_many :chunks, -> { order(:position) }, dependent: :destroy

  # Lifecycle through the ingestion pipeline. `removed` = tombstoned (gone from source).
  enum :status, {
    pending: "pending",
    processing: "processing",
    processed: "processed",
    failed: "failed",
    removed: "removed"
  }, default: "pending"

  validates :external_id, presence: true, uniqueness: { scope: :source_id }

  # "Unsorted": live documents in no collection. A derived view, not a real
  # collection — a removed (tombstoned) doc is gone from its source, so it isn't
  # unsorted, just dead.
  scope :unsorted, -> {
    where.not(status: "removed").where.not(id: CollectionMembership.active.select(:document_id))
  }

  # Two different questions, deliberately kept apart.
  #
  # **Retrievable** — what a query may draw on. Strictly through collections,
  # which is what the access model says: a document in no collection is in
  # nobody's corpus. This is the one that governs search, and chat when it
  # lands.
  scope :retrievable_by, ->(user) {
    next all if user.admin?

    where(id: CollectionMembership.active
      .where(collection_id: Collection.readable_by(user).select(:id))
      .select(:document_id))
  }

  # **Reachable** — what a person may open or download directly. Everything
  # retrievable, plus two cases that aren't reached through a collection at all:
  # documents from a source you own (your own uploads, always yours), and — for
  # operators — unfiled documents, because /unsorted is the queue for filing
  # exactly those and you cannot file what you cannot open.
  scope :reachable_by, ->(user) {
    next all if user.admin?

    reachable = retrievable_by(user).or(where(source_id: user.sources.select(:id)))
    next reachable unless user.at_least?(:operator)

    reachable.or(unsorted)
  }

  # Live-update the show page as the pipeline advances. Broadcast synchronously
  # from whatever updated the status (the job), not *_later — see the streaming
  # notes in the architecture: async broadcasts race and arrive out of order.
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def broadcast_status_change
    broadcast_replace_to(
      self,
      target: ActionView::RecordIdentifier.dom_id(self),
      html: Views::Documents::Detail.new(document: self).call
    )
  end
end
