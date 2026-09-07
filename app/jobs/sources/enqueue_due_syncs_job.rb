module Sources
  # The scheduler tick. Runs on an interval from config/recurring.yml and starts
  # a sync for every source that is due for one.
  #
  # Per-source intervals live in each source's own config, so the recurring
  # entry is a fixed heartbeat and the decision of what is actually due is a
  # query — `Source.due_for_sync`. Adding a source, or changing its
  # interval, needs no change to the schedule.
  class EnqueueDueSyncsJob < ApplicationJob
    queue_as :ingestion

    def perform
      Source.due_for_sync.find_each do |source|
        SyncJob.perform_later(source)
      end
    end
  end
end
