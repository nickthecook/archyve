# One run of a source's sync. Records the diff the scan produced (what was
# created / updated / left alone / tombstoned) and, through the documents that
# point back at it, how far the resulting processing has got.
#
# The two halves finish at different times and are tracked differently on
# purpose. The **scan** is synchronous inside Sources::SyncJob, so its counts
# are complete the moment `status` leaves `running` — nothing else will change
# them. **Processing** continues afterwards in per-document jobs, and rather
# than have those jobs decrement a shared counter (which a crashed worker leaves
# stuck forever), progress is read straight off the documents they update. The
# durable record is the answer; there is no separate tally to keep in step.
class SourceSync < ApplicationRecord
  belongs_to :source

  # Documents this run created or updated. Nullified, not destroyed, when a run
  # is pruned: the document outlives the record of how it arrived.
  has_many :documents, dependent: :nullify

  enum :status, {
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: "running"

  scope :recent, -> { order(started_at: :desc) }

  # Push the source page's live region when a scan starts and when it ends.
  # Synchronously, not *_later: async broadcasts race and can arrive out of
  # order, which would leave "scanning…" showing after the run had finished.
  #
  # Only the run's own transitions are broadcast. The documents it produces move
  # far more often, and re-rendering this panel for each of them would be
  # thousands of broadcasts to nudge an aggregate — that progress is polled from
  # the region instead.
  after_commit :broadcast_to_source, on: [:create, :update]

  # A scan that never reported back — its worker died mid-run. Nothing rescues
  # these automatically yet; the source page shows them as stalled so a
  # re-sync is an obvious next step.
  scope :stalled, ->(after: 1.hour) { running.where(started_at: ...after.ago) }

  def duration
    return unless finished_at

    finished_at - started_at
  end

  # How the documents this run put through the pipeline are progressing, e.g.
  # {"pending" => 4, "processing" => 1, "processed" => 112, "failed" => 2}.
  #
  # Tombstoned documents are excluded even though they point at this run — the
  # run is recorded on them because it is what retired them, which is worth
  # knowing, but they were never handed to the pipeline. Counting them here
  # inflates the denominator with work that will never happen: a scan that
  # created 3 and removed 3 would report "3 of 6", and the bar could never fill,
  # since `removed` isn't a segment the meter draws.
  def pipeline_statuses
    documents.where.not(status: :removed).group(:status).count
  end

  # True once nothing this run produced is still queued or mid-pipeline. Asked
  # of the documents rather than a counter, so a worker that died leaves a
  # visible `processing` document instead of a total that never lands on zero.
  def processing_finished?
    !documents.where(status: [:pending, :processing]).exists?
  end

  # Documents whose processing failed after the scan handed them off. Distinct
  # from `failed_count`, which counts items the scan itself errored on.
  def processing_failures
    documents.failed
  end

  private

  def broadcast_to_source
    broadcast_replace_to(
      source,
      target: Views::Sources::LastScan.dom_id(source),
      html: Views::Sources::LastScan.new(source: source).call
    )
  end
end
