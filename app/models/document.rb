class Document < ApplicationRecord
  belongs_to :source

  # The sync run that last created or updated this document. Optional: manually
  # uploaded documents never had one, and it is nullified when an old run is
  # pruned. It is what lets a run report its own processing progress.
  belongs_to :source_sync, optional: true

  # The run that last *saw* this document in its source, whether or not it
  # changed. Kept apart from `source_sync` because that one is what
  # SourceSync#documents hangs off, and stamping every unchanged document onto a
  # run would pull the whole archive into that run's pipeline meter. This is how
  # Sources::Sync decides what has vanished, so a scan split across several jobs
  # can still answer it.
  belongs_to :last_seen_sync, class_name: "SourceSync", optional: true

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

  # The statuses the pipeline won't move off on its own. This is what "still
  # working" means to anything watching a document — a live region polls until
  # everything it shows is settled, then stops.
  TERMINAL_STATUSES = %w[processed failed removed].freeze

  def settled? = TERMINAL_STATUSES.include?(status)

  validates :external_id, presence: true, uniqueness: { scope: :source_id }

  # The outcome vocabulary lives with the pipeline that produces it
  # (Ingestion::Outcome); the columns only refuse anything outside it, so a
  # typo can't reach a view that has no words for it. Both stay nullable — a
  # document that came through cleanly has nothing to say, and rows that failed
  # before any of this existed have nothing to say either.
  validates :outcome_kind, inclusion: { in: Ingestion::Outcome::KINDS }, allow_nil: true
  validates :outcome_stage, inclusion: { in: Ingestion::Outcome::STAGES }, allow_nil: true

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
  # retrievable, plus everything produced by a source they manage.
  #
  # That second clause is what makes /unsorted work: an unfiled document is in
  # no collection, so nothing retrieves it, but whoever manages the source that
  # produced it can still open it — and filing it is exactly what they are
  # there to do. It also covers your own uploads, since owning a source counts
  # as administering it.
  scope :reachable_by, ->(user) {
    next all if user.admin?
    next retrievable_by(user) unless user.at_least?(:operator)

    retrievable_by(user).or(where(source_id: Source.manageable_by(user).select(:id)))
  }

  # --- pipeline outcome ------------------------------------------------------

  # Queued for a run, and actually running. Both forget the last run's verdict:
  # a stale diagnosis that outlives a reprocess is worse than none at all,
  # because it reads as current. The first exists so that clicking Reprocess
  # changes the page immediately rather than leaving a red badge sitting there
  # until a worker gets round to the job.
  def queue_for_processing! = enter_pipeline!(:pending)
  def begin_processing! = enter_pipeline!(:processing)

  def record_failure!(outcome) = record_outcome!(outcome, status: :failed)

  # Processed, with a caveat. The status is the honest one — the document is in
  # the archive and will be retrieved from — and the caveat rides alongside
  # rather than downgrading it.
  def record_shortfall!(outcome) = record_outcome!(outcome, status: :processed)

  # Came through with something missing: searchable, but not the whole
  # document. Distinct from `failed?`, and the distinction is the whole reason
  # these columns aren't called `failure_*`.
  def shortfall? = processed? && outcome_kind.present?

  # Whether to OCR this document when extracting it.
  #
  # Null is not "no" — it means "whatever the source says". That is what a
  # connector's documents want: change the source's setting, reprocess, and
  # they follow. A manual upload stores an explicit answer instead, because the
  # person uploading was asked one file at a time and their answer has to
  # survive a reprocess months later.
  def ocr? = ocr.nil? ? source.ocr? : ocr

  # Whether re-running the pipeline is worth offering. Not gated on having
  # settled: `limits_concurrency` on the job already serializes a second run
  # behind a first, and the job is idempotent, so the honest answer to "can
  # this be reprocessed?" doesn't depend on what the pipeline is doing right
  # now. A tombstone is the real exclusion — a removed document is gone from
  # its source, and re-ingesting it would undo that.
  def reprocessable? = !removed? && file.attached?

  # Whether deleting this actually removes it from the archive. A syncable source
  # re-creates its documents on the next scan, so there the deletion belongs at
  # the source; a tombstone has already left the source and won't come back.
  def purgeable? = removed? || !source.supports_sync?

  # Live-update the show page as the pipeline advances. Broadcast synchronously
  # from whatever updated the status (the job), not *_later — see the streaming
  # notes in the architecture: async broadcasts race and arrive out of order.
  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def enter_pipeline!(status)
    update!(status: status, outcome_stage: nil, outcome_kind: nil, outcome_detail: nil)
  end

  def record_outcome!(outcome, status:)
    update!(
      status: status,
      outcome_stage: outcome.stage,
      outcome_kind: outcome.kind,
      outcome_detail: outcome.detail
    )
  end

  def broadcast_status_change
    broadcast_replace_to(
      self,
      target: ActionView::RecordIdentifier.dom_id(self),
      html: Views::Documents::Detail.new(document: self).call
    )
    broadcast_diagnostics_change
  end

  # The operator's panel rides a stream of its own, because the document's
  # shared stream reaches every reader who can open the page and what this
  # carries — raw error text naming hosts, models and paths — is not theirs to
  # read. A non-operator's page never renders the subscription, and Turbo signs
  # stream names, so it can't be joined by guessing one.
  #
  # Its own region, too, rather than a branch inside Detail: Detail is rendered
  # from here, inside a job, where there is no Current.user to ask `may?` about
  # — it would render as though nobody were looking.
  def broadcast_diagnostics_change
    broadcast_replace_to(
      self, :diagnostics,
      target: Views::Documents::Diagnostics.dom_id(self),
      html: Views::Documents::Diagnostics.new(document: self).call
    )
  end
end
