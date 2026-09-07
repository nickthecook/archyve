module Connectors
  # Scans one connector. Thin by design — the reconciliation lives in
  # Connectors::Sync, this just gives it a queue, a lock, and a place to fail.
  class SyncJob < ApplicationJob
    queue_as :ingestion

    # One scan per connector at a time. Two concurrent scans of the same source
    # would both diff against the same starting state and both act on it —
    # double-enqueueing imports, and racing each other's tombstones.
    # `Connector.due_for_sync` already skips connectors mid-sync, so this is the
    # backstop for the paths that don't consult it, like the Sync now button.
    limits_concurrency key: ->(connector) { connector.id }, to: 1, duration: 1.hour

    def perform(connector)
      Connectors::Sync.call(connector)
    end
  end
end
