module Connectors
  # The scheduler tick. Runs on an interval from config/recurring.yml and starts
  # a sync for every connector that is due for one.
  #
  # Per-connector intervals live in each connector's own config, so the recurring
  # entry is a fixed heartbeat and the decision of what is actually due is a
  # query — `Connector.due_for_sync`. Adding a connector, or changing its
  # interval, needs no change to the schedule.
  class EnqueueDueSyncsJob < ApplicationJob
    queue_as :ingestion

    def perform
      Connector.due_for_sync.find_each do |connector|
        SyncJob.perform_later(connector)
      end
    end
  end
end
