module Sources
  # Retires scan runs that stopped reporting progress — a worker that died
  # mid-pass, or mid-pause with nothing left to resume it.
  #
  # This is not housekeeping. `Source.due_for_sync` excludes any source with a
  # `running` scan, and nothing else clears one, so an abandoned run blocks its
  # source from ever syncing again. Before scans could span jobs that took a
  # crash to arrange; now it is the ordinary cost of a deploy landing mid-scan.
  class SweepStalledSyncsJob < ApplicationJob
    queue_as :ingestion

    def perform
      SourceSync.stalled.find_each do |run|
        Rails.logger.warn("Sweeping stalled sync #{run.id} for source #{run.source_id}")

        # Failed, not completed: the scan never reached the end of its source,
        # so its view of what is there is partial and must not be read as
        # authoritative. `Sources::Sync` only tombstones on a pass that drained,
        # and retiring this one as completed would imply it had.
        run.retire!(status: :failed, error: run.error.presence || "worker did not report back")
      end
    end
  end
end
