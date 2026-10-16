module BackgroundJobs
  # Finished job rows are kept for SolidQueue.clear_finished_jobs_after and then
  # dropped; nothing else prunes them. Batched with a pause between, so clearing
  # a long backlog doesn't hold the queue's database in one transaction.
  class SweepFinishedJob < ApplicationJob
    queue_as :default

    SLEEP_BETWEEN_BATCHES = 0.3

    def perform
      SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: SLEEP_BETWEEN_BATCHES)
    end
  end
end
