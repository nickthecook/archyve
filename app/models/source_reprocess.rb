# One run of a source's bulk reprocess: re-extracting documents already in the
# archive, from the files already stored, because the pipeline changed rather
# than the source did. Not a sync — nothing is fetched.
#
# Documents are enqueued in a moving window rather than all at once. A source
# with thousands of documents dropped into the queue in one go puts all of them
# ahead of the next upload, and leaves nothing to cancel: the work is already
# handed over. The window is what makes stopping mean something, because most of
# the run has not been enqueued yet when the button is pressed.
#
# `enqueued` counts what this run handed to the queue, which one serialized job
# can be trusted to tally. How far *processing* has got is read off the
# documents instead — a counter that a crashed worker forgot to decrement stays
# wrong forever.
class SourceReprocess < ApplicationRecord
  belongs_to :source

  enum :status, {
    running: "running",
    cancelled: "cancelled",
    completed: "completed"
  }, default: "running"

  TERMINAL_STATUSES = %w[cancelled completed].freeze

  def settled? = TERMINAL_STATUSES.include?(status)

  # Documents this run has yet to hand over, oldest first. The cursor is an id
  # rather than an offset so that documents arriving mid-run don't shuffle the
  # ones behind them out of the way.
  def candidates = source.documents.reprocessable.where("documents.id > ?", cursor).order(:id)

  # Work the source has in the pipeline right now, whatever put it there. A sync
  # running alongside counts too, which is the point: the window is about how
  # much this source is asking of Docling, not about bookkeeping.
  def in_flight = source.documents.where(status: %w[pending processing]).count

  def record_enqueued!(batch)
    update!(cursor: batch.last.id, enqueued: enqueued + batch.size)
  end

  def cancel! = update!(status: :cancelled, finished_at: Time.current)
  def complete! = update!(status: :completed, finished_at: Time.current)
end
