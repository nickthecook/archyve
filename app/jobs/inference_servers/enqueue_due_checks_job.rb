module InferenceServers
  # The scheduler tick. Runs on an interval from config/recurring.yml and probes
  # every server whose status has gone stale.
  #
  # Same shape as Sources::EnqueueDueSyncsJob, and for the same reason: the
  # recurring entry is a fixed heartbeat, and what is actually due is a query —
  # `InferenceServer.due_for_check`. It fans out one job per server rather than
  # checking them inline, so a host that hangs until its timeout delays only its
  # own check and not everybody else's.
  class EnqueueDueChecksJob < ApplicationJob
    queue_as :default

    def perform
      InferenceServer.due_for_check.find_each do |server|
        CheckJob.perform_later(server)
      end
    end
  end
end
