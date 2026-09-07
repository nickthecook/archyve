module Sources
  # Scans one source. Thin by design — the reconciliation lives in
  # Sources::Sync, this just gives it a queue, a lock, and a place to fail.
  class SyncJob < ApplicationJob
    queue_as :ingestion

    # One scan per source at a time. Two concurrent scans of the same source
    # would both diff against the same starting state and both act on it —
    # double-enqueueing imports, and racing each other's tombstones.
    # `Source.due_for_sync` already skips sources mid-sync, so this is the
    # backstop for the paths that don't consult it, like the Sync now button.
    limits_concurrency key: ->(source) { source.id }, to: 1, duration: 1.hour

    def perform(source)
      Sources::Sync.call(source)
    end
  end
end
