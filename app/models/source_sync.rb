# One run of a source's sync. Records the diff the scan produced (what was
# created / updated / left alone / tombstoned) and, through the documents that
# point back at it, how far the resulting processing has got.
#
# The two halves finish at different times and are tracked differently on
# purpose. The **scan** may span several `Sources::SyncJob`s — a source whose
# enumeration is expensive stops on a wall-clock budget and resumes on the next
# tick — so its counts accumulate across passes and are final only once `status`
# reaches a terminal one. **Processing** continues afterwards in per-document
# jobs, and rather than have those jobs decrement a shared counter (which a
# crashed worker leaves stuck forever), progress is read straight off the
# documents they update. The durable record is the answer; there is no separate
# tally to keep in step.
class SourceSync < ApplicationRecord
  belongs_to :source

  # Items this run has something to remember about — today, the ones that
  # failed. Destroyed with the run: they describe the run, not the archive.
  has_many :items, class_name: "SourceSyncItem", dependent: :destroy

  # Documents this run created or updated. Nullified, not destroyed, when a run
  # is pruned: the document outlives the record of how it arrived.
  has_many :documents, dependent: :nullify

  # `running` and `paused` are both mid-scan, and the difference is whether a
  # job holds the run right now. A scan that stops on its budget can be neither
  # of the terminal states: `completed` would tombstone against a partial view
  # of the source, and `failed` would stamp `source.last_synced_at`, making the
  # source wait out its whole interval before resuming what it was in the middle
  # of.
  enum :status, {
    running: "running",
    paused: "paused",
    completed: "completed",
    failed: "failed"
  }, default: "running"

  # The scan is over, one way or another. Its counts will not move again.
  TERMINAL_STATUSES = %w[completed failed].freeze

  scope :recent, -> { order(started_at: :desc) }
  scope :unfinished, -> { where(status: [:running, :paused]) }

  def finished? = TERMINAL_STATUSES.include?(status)

  # Close a run for good. The two steps belong together and in this order: the
  # histogram is the durable form of the item rows, and reaping them without it
  # loses the only account of how the run went.
  #
  # Both endings come through here. A run the sweeper retires is as final as one
  # that ran to the end of its source, and is the ending more likely to leave a
  # large crawl's frontier behind.
  def retire!(status:, error: nil, **attributes)
    update!(**attributes, status: status, error: error,
      finished_at: Time.current, response_stats: items.histogram)

    items.spent.delete_all
  end

  # Push the source page's live region when a scan starts and when it ends.
  # Synchronously, not *_later: async broadcasts race and can arrive out of
  # order, which would leave "scanning…" showing after the run had finished.
  #
  # Only status transitions, not every save. A long scan touches
  # `last_progress_at` as it goes, and re-rendering the whole panel on each of
  # those would be a broadcast every few seconds for hours to move a timestamp
  # nothing displays. The documents it produces move far more often still, which
  # is why their progress is polled from the region instead.
  after_commit :broadcast_to_source, on: [:create, :update], if: :status_transition?

  # How long a mid-scan run may go without reporting progress before it is
  # presumed dead. Generous next to the scan budget in Sources::Sync, which is
  # what a healthy run's heartbeat is paced by.
  STALL_AFTER = 1.hour

  # A scan that stopped reporting — its worker died mid-run, or mid-pause.
  # Judged on progress rather than `started_at`, because a resumable scan is
  # legitimately hours old while still advancing every pass.
  scope :stalled, ->(after: STALL_AFTER) {
    unfinished.where(last_progress_at: ...after.ago)
      .or(unfinished.where(last_progress_at: nil).where(started_at: ...after.ago))
  }

  def stalled?(after: STALL_AFTER)
    return false if finished?

    (last_progress_at || started_at) < after.ago
  end

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

  def status_transition?
    previously_new_record? || saved_change_to_status?
  end

  def broadcast_to_source
    broadcast_replace_to(
      source,
      target: Views::Sources::LastScan.dom_id(source),
      html: Views::Sources::LastScan.new(source: source).call
    )
  end
end
