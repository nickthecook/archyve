module Sources
  # Feeds a source's documents back through extraction, a window at a time.
  #
  # The job does not convert anything itself; it hands documents to
  # ProcessDocumentJob and re-schedules itself to top the window up as they
  # drain. Two things fall out of that shape, and both are the reason for it:
  # the docling queue never fills with one source's backlog, and a run can be
  # stopped, because most of it has not been handed over yet.
  #
  # Runs on `ingestion`, not `docling`. This job waits and counts; occupying one
  # of the two conversion threads to do it would be self-defeating.
  class ReprocessJob < ApplicationJob
    queue_as :ingestion

    # One walker per run. Without this the re-schedule below can overlap with a
    # sweep or a retry and enqueue the same window twice.
    limits_concurrency key: ->(run) { run.source_id }, to: 1, duration: 30.minutes

    # Behind everything a person is waiting on. Solid Queue orders ready work by
    # priority before id, so an upload enqueued at the default 0 goes ahead of
    # a backlog of these however long it already is.
    PRIORITY = 50

    # How much of this source to allow in the pipeline at once, and how often to
    # look. The window is a throttle second and a cancellation budget first: it
    # is the most work a stop button cannot call back.
    WINDOW = 25
    POLL = 10.seconds

    def perform(run)
      return unless run.running?

      batch = next_batch(run)
      return run.complete! if batch.nil?

      hand_over(run, batch) if batch.any?
      self.class.set(wait: POLL).perform_later(run)
    end

    private

    # nil means the run is out of documents — distinct from an empty batch,
    # which means the window is full and there is more to come.
    def next_batch(run)
      room = WINDOW - run.in_flight
      return [] if room <= 0

      batch = run.candidates.limit(room).to_a
      batch.presence
    end

    # Not `enqueue`: that is ActiveJob's own, and perform_later calls it.
    def hand_over(run, batch)
      # update_all, not a save apiece: each document's status callback rebuilds
      # and broadcasts its whole show page, which at this size is the expensive
      # part of the operation and nobody is watching most of it. The pages that
      # are open poll, and the job broadcasts properly once it starts.
      Document.where(id: batch.map(&:id)).update_all(
        status: "pending", outcome_stage: nil, outcome_kind: nil, outcome_detail: nil,
        updated_at: Time.current
      )
      ActiveJob.perform_all_later(batch.map { queued_job(it) })
      run.record_enqueued!(batch)
    end

    def queued_job(document)
      ProcessDocumentJob.new(document).tap { it.priority = PRIORITY }
    end
  end
end
