module InferenceServers
  # Probes one server. Thin by design — #check! already records both outcomes
  # and swallows everything, so there is nothing here to rescue and nothing to
  # report: the result *is* the row.
  class CheckJob < ApplicationJob
    queue_as :default

    # A server removed between the tick and the run has nothing to check, and a
    # deleted record is not a failure worth retrying.
    discard_on ActiveJob::DeserializationError

    # One probe per server at a time. A host that hangs until its timeout can
    # easily outlive the tick that enqueued it — Ollama discovery is one call per
    # model pulled on the host, at DISCOVERY_TIMEOUT each — and the tick comes
    # round every five minutes regardless.
    #
    # :discard, not the default :block, because a probe is only worth running
    # *now*. Blocking would queue a dozen identical checks behind a sick host and
    # then run them all at once when it recovered, each overwriting the last with
    # the same answer. Dropping the duplicate loses nothing: the next tick after
    # the lock frees enqueues a fresh one.
    limits_concurrency key: ->(server) { server.id }, to: 1, duration: 1.hour, on_conflict: :discard

    def perform(server)
      server.check!
    end
  end
end
