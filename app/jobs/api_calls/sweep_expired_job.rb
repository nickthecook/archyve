module ApiCalls
  # Recorded calls are debugging exhaust carrying request and response bodies,
  # so they expire on a timer rather than waiting for someone to remember the
  # table exists. ApiCall::RETENTION is the age.
  class SweepExpiredJob < ApplicationJob
    queue_as :default

    def perform
      ApiCall.expired.in_batches.delete_all
    end
  end
end
